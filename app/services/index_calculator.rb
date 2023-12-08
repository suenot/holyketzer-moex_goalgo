class IndexCalculator
  REVIEW_PERIOD = "review_period".freeze
  REVIEW_PERIOD_Q = "quarterly".freeze
  REVIEW_PERIOD_Y = "yearly".freeze

  FILTERS = "filters".freeze
  FILTERS_LL = "listing_level".freeze
  FILTERS_SECTOR = "sector".freeze
  FILTERS_TICKERS = "tickers".freeze

  SELECTION = "selection".freeze
  SELECTION_MARKET_CAP = "market_cap".freeze
  SELECTION_MOMENTUM = "momentum".freeze
  SELECTION_TOP = "top".freeze
  SELECTION_PERIOD = "period".freeze
  SELECTION_BENCHMARK = "benchmark".freeze

  MOMENTUM_DROP_HIGH_BETA = 0.1
  MOMENTUM_PICK_HIGH_RETURN = 0.5
  MOMENTUM_MIN_DAYS = 100

  WEIGHING = "weighing".freeze
  WEIGHING_EQUAL = "equal".freeze
  WEIGHING_MARKET_CAP = "market_cap".freeze

  INDEX_START_POINT = 1_000
  INDEX_START_MONEY = 1_000_000_000

  class ShareCoeffs
    attr_reader :share_id, :beta, :returns

    def initialize(share_id:, beta:, returns:)
      @share_id = share_id
      @beta = beta
      @returns = returns
    end
  end

  class << self
    def build_index(custom_index)
      custom_index.update!(status: "in_progress", progress: 0)

      settings = custom_index.settings
      prev_index_items = []
      index_items_per_period = date_iterator(settings[REVIEW_PERIOD]) do |date|
        share_caps = filter_shares(date, settings[FILTERS])
        share_caps = select_shares(share_caps, date, settings[SELECTION])
        share_cap_by_weight = weigh_shares(share_caps, settings[WEIGHING])
        index_items = create_index_items(custom_index, date, share_cap_by_weight, prev_index_items)

        puts "#{date} #{share_caps.size} shares #{share_caps.map(&:secid).join(", ")}"
        prev_index_items = index_items
      end.reject(&:empty?)

      last_date = nil
      total_count = index_items_per_period.size
      i = 0
      index_items_per_period.each_cons(2) do |prev_index_items, index_items|
        from_date = prev_index_items.first.date
        to_date = index_items.first.date - 1.day
        create_index_prices(custom_index, from_date, to_date, prev_index_items)
        last_date = to_date
        i += 1
        custom_index.update!(progress: (i * 100 / total_count))
      end

      if last_date
        create_index_prices(custom_index, last_date, Date.today, index_items_per_period[-1])
      end

      index_items_per_period.size.tap do |size|
        custom_index.update!(status: "done", progress: 100)
      end
    end

    def filter_shares(date, filters)
      share_caps = ShareCap.where(date: date)

      filters.each do |filter_key, filter_value|
        case filter_key
        when FILTERS_LL
          share_caps = share_caps.where(share_id: Share.where(list_level: filter_value).select(:id))
        when FILTERS_TICKERS
          share_caps = share_caps.where(secid: filter_value)
        when FILTERS_SECTOR
          share_caps = share_caps.where(share_id: Share.where(share_sector_id: filter_value).select(:id))
        else
          raise "Unknown filter #{filter}"
        end
      end

      share_caps
    end

    private

    def select_shares(share_caps, date, selection)
      selection_key, selection_value = *selection
      case selection_key
      when SELECTION_MARKET_CAP
        share_caps = share_caps.order(cap: :desc).limit(selection_value[SELECTION_TOP])
      when SELECTION_MOMENTUM
        share_ids = select_with_momentum(share_caps, date, selection_value[SELECTION_PERIOD], selection_value[SELECTION_BENCHMARK])
        share_caps = share_caps.where(share_id: share_ids)#.limit(selection_value[SELECTION_TOP])
      else
        raise "Unknown selection #{selection}"
      end
    end

    # https://at6.livejournal.com/29233.html
    # https://alphaarchitect.com/2015/12/quantitative-momentum-investing-philosophy/
    def select_with_momentum(share_caps, date, period_days, benchmark_index)
      shares_index = SharesIndex.where(secid: benchmark_index).first
      index_prices_by_date = IndexPrice.where(shares_index: shares_index)
        .where("date <= ?", date)
        .where("date >= ?", date - period_days.days)
        .where("close > 0")
        .order(date: :asc)
        .pluck(:date, :close)

      share_coeffs = share_caps.map do |share_cap|
        share_prices_by_date = SharePrice.where(share: share_cap.share)
          .where("date <= ?", date)
          .where("date >= ?", date - period_days.days)
          .where("close > 0")
          .order(date: :asc)
          .pluck(:date, :close)

        index_prices, share_prices = *allign_prices(index_prices_by_date, share_prices_by_date)
        index_vector = Daru::Vector.new(relative_growth(index_prices))
        share_vector = Daru::Vector.new(relative_growth(share_prices))

        if index_vector.size > MOMENTUM_MIN_DAYS
          ShareCoeffs.new(
            share_id: share_cap.share_id,
            beta: (share_vector.covariance_population(index_vector) / index_vector.variance_population).to_f,
            returns: ((share_prices.last - share_prices.first) / share_prices.first).to_f,
          )
        else
          nil
        end
      end

      share_coeffs = share_coeffs.compact
      share_coeffs = share_coeffs.sort_by(&:beta).take((share_coeffs.size*(1-MOMENTUM_DROP_HIGH_BETA)).to_i)
      share_coeffs = share_coeffs.sort_by(&:returns).take((share_coeffs.size*MOMENTUM_PICK_HIGH_RETURN).to_i)
      share_coeffs.map(&:share_id)
    end

    def allign_prices(index_prices, share_prices)
      index_vector = []
      share_vector = []

      share_prices = share_prices.to_h
      index_prices.each do |index_date, index_price|
        if (share_price = share_prices[index_date])
          index_vector << index_price
          share_vector << share_price
        end
      end

      [index_vector, share_vector]
    end

    def relative_growth(prices)
      res = []
      prices.each_cons(2) do |prev_price, price|
        res << (price - prev_price) / prev_price.to_f
      end
      res
    end

    def weigh_shares(share_caps, weighing)
      case weighing
      when WEIGHING_EQUAL
        share_caps.map { |share_cap| [share_cap, 1.0 / share_caps.size] }.to_h
      when WEIGHING_MARKET_CAP
        total_cap = share_caps.sum { |x| BigDecimal(x.cap) }
        share_caps.map { |share_cap| [share_cap, share_cap.cap / total_cap] }.to_h
      else
        raise "Unknown weighing `#{weighing}`"
      end
    end

    def create_index_items(custom_index, date, share_cap_by_weight, prev_index_items)
      if share_cap_by_weight.size == 0
        return []
      end

      share_ids = share_cap_by_weight.keys.map(&:share_id) + prev_index_items.map(&:share_id)
      prices_by_share_id = load_last_prices(share_ids, date)

      if prev_index_items.size > 0
        total_money = prev_index_items.sum { |item| item.shares_count * prices_by_share_id[item.share_id] }
      else
        total_money = INDEX_START_MONEY
        custom_index.update!(coeff_d: total_money / INDEX_START_POINT)
      end

      puts "Total sum of weight=#{share_cap_by_weight.values.sum} #{share_cap_by_weight.size} #{share_cap_by_weight.values}"

      CustomIndexItem.transaction do
        CustomIndexItem.where(custom_index: custom_index, date: date).delete_all

        share_cap_by_weight.map do |share_cap, weight|
          shares_count = (total_money * weight / prices_by_share_id[share_cap.share_id])

          CustomIndexItem.create!(
            custom_index: custom_index,
            share: share_cap.share,
            date: date,
            shares_count: shares_count,
            weight: weight,
          )
        end
      end
    end

    def create_index_prices(custom_index, from_date, to_date, index_items)

      (from_date..to_date).each do |date|
        share_ids = index_items.map(&:share_id)
        prices_by_share_id = {}
        SharePrice.where(share_id: share_ids, date: date).where("open > 0 and close > 0").each do |share_price|
          prices_by_share_id[share_price.share_id] = share_price
        end

        if prices_by_share_id.size == share_ids.size
          CustomIndexPrice.transaction do
            CustomIndexPrice.where(custom_index: custom_index, date: date).delete_all

            CustomIndexPrice.create!(
              custom_index: custom_index,
              date: date,
              open: calc_index_points(index_items, prices_by_share_id, custom_index, :open),
              close: calc_index_points(index_items, prices_by_share_id, custom_index, :close),
              # low: calc_index_points(index_items, prices_by_share_id, custom_index, :low),
              # high: calc_index_points(index_items, prices_by_share_id, custom_index, :high),
              # volume: 0,
            )
          end
        else
          puts "Not all prices for #{date} #{custom_index.name}"
        end
      end
    end

    def calc_index_points(index_items, prices_by_share_id, custom_index, price_attr)
      total = index_items.sum do |index_item|
        index_item.shares_count * prices_by_share_id[index_item.share_id].send(price_attr)
      end
      total / custom_index.coeff_d
    end

    def load_last_prices(share_ids, date)
      SharePrice.joins(
        <<~SQL
          JOIN (
            SELECT share_id, MAX(date) AS max_date
            FROM share_prices
            WHERE date <= '#{date}' and share_id in (#{share_ids.join(", ")}) and close > 0
            GROUP BY share_id
          ) mdp ON share_prices.share_id = mdp.share_id AND share_prices.date = mdp.max_date
        SQL
      ).map do |price|
        # Fail fast in case of too old price
        if date - price.date > 7.days
          raise "Too price for #{price.share.secid} on #{date}"
        end
        [price.share_id, price.close]
      end.to_h
    end

    def date_iterator(period)
      start = SharePrice.minimum("date")
      case period
      when REVIEW_PERIOD_Q
        start = start.end_of_quarter
        step = 3.months
        method = "end_of_quarter"
      when REVIEW_PERIOD_Y
        start = start.end_of_year
        step = 1.year
        method = "end_of_year"
      else
        raise "Unknown period #{period}"
      end

      res = []
      while start < Date.today
        start = start.send(method)
        res << (yield start)
        start += step
      end
      res
    end
  end
end

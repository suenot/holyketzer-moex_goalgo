class CapCalculator
  class << self
    def calc
      ShareMacroStat.find_each do |share_macro_stat|
        share_price = SharePrice.where(share_id: share_macro_stat.share_id)
          .where("date <= ?", share_macro_stat.date)
          .where("waprice > 0")
          .order(date: :desc)
          .limit(1)
          .first

        if share_price
          diff = share_macro_stat.date - share_price.date
          puts "#{share_price.secid} #{share_macro_stat.date} diff: #{diff}"
          if diff > 7.days
            raise "diff > 7.days"
          end

          share_cap = calculate_share_cap(share_macro_stat.shares_count, share_price)
          share_macro_stat.update(cap: share_cap)
        else
          puts "No share price for #{share_macro_stat.secid} #{share_macro_stat.date}"
        end
      end
    end

    private

    def calculate_share_cap(shares_count, share_price)
      shares_count * share_price.waprice
    rescue StandardError => e
      p share_price
      raise e
    end
  end
end

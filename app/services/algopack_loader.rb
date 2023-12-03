class AlgopackLoader
  include Singleton

  START_DATE = Date.parse("1997-03-24")

  def load_shares(skip_existing: false)
    # Fetch all pages of shares with pagination
    loaded_secids = Share.pluck(:secid).to_set

    offset = 0
    begin
      shares = AlgopackFetcher.instance.fetch_shares(offset: offset, limit: 100)

      shares.each do |share|
        # Save the share information to the DB using the Security model
        if skip_existing && loaded_secids.include?(share["secid"])
          next
        end

        if !Share::SHARE_TYPES.include?(share["type"])
          next
        end

        # Fetch information of the particular share
        share_info = AlgopackFetcher.instance.fetch_share(share["secid"])

        attrs = {
          secid: share_info["secid"],
          name: share_info["name"],
          short_name: share_info["shortname"],
          isin: share_info["isin"] || Share::NO_ISIN,
          issue_size: share_info["issuesize"].to_i,
          nominal_price: Money.new(share_info["facevalue"].to_f*100, share_info["faceunit"]),
          issue_date: share_info["issuedate"],
          history_from: share_info["history_from"],
          list_level: share_info["listlevel"].to_i,
          sec_type: share_info["type"],
        }
        if (share = Share.find_by(secid: share_info["secid"]))
          share.update!(attrs)
        else
          share = Share.new(attrs)
          share.save!
        end
      end
      offset += shares.size
    end while shares.size > 0
  end

  def load_cap
    caps = AlgopackFetcher.instance.fetch_shares_cap

    caps.compact.each do |secid, cap|
      if (share = Share.find_by(secid: secid))
        share.update!(cap: cap)
      end
    end
  end

  def load_shares_count
    version = 1
    shares = Share.where("version < ?", version)

    shares.each do |share|
      if (counts = SmartlabListedSharesFetcher.instance.fetch_for(share.secid))
        counts.each do |date, count|
          if count != nil
            ShareMacroStat.create!(
              share: share,
              secid: share.secid,
              date: date,
              shares_count: count,
            )
          end
        end
      end
      share.update!(version: version)
    end
  end

  def load_all_history_prices
    secids = ShareMacroStat.pluck("distinct(secid)")
    secids.each do |secid|
      label = "#{secid} (#{secids.index(secid)+1}/#{secids.size})"
      puts "Loading history prices for #{label}"
      share = Share.find_by(secid: secid)
      from = SharePrice.where(secid: secid).order(date: :desc).first&.date
      if from
        from += 1.day
      else
        from = START_DATE
      end

      prev_from = from - 1.day
      while from < Date.today && prev_from != from
        puts "Loading history prices for #{label} from #{from}"
        prev_from = from

        prices = AlgopackFetcher.instance.fetch_history_prices(secid, from: from, to: Date.today)

        attrs = prices.map do |price|
          date = Date.parse(price["tradedate"])
          from = date + 1.day

          {
            share_id: share.id,
            secid: secid,
            date: date,
            open: price["open"],
            close: price["close"],
            low: price["low"],
            high: price["high"],
            volume: price["volume"].to_i,
            waprice: price["waprice"],
          }
        end

        SharePrice.insert_all(attrs)
      end
    end
  end
end

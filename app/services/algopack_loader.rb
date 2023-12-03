class AlgopackLoader
  include Singleton

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
end

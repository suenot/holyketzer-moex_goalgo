class AlgopackFetcher
  include Singleton

  BASE_URL = "https://iss.moex.com/iss"
  START_DATE = Date.parse("1997-03-24")

  def initialize
  end

  def fetch_shares(offset: 0, limit: 100)
    response = HTTP.get(
      [
        "#{BASE_URL}/securities.json?engine=stock",
        "market=shares",
        "type=common_share",
        "iss.meta=off",
        "start=#{offset}",
        "limit=#{limit}"
      ].join("&")
    )

    if response.status.success?
      securities = JSON.parse(response.body.to_s)["securities"]
      columns = securities["columns"]
      data = securities["data"]
      data.map do |row|
        Hash[columns.zip(row)]
      end
    else
      raise "Error fetching shares: #{response.status} #{response.body.to_s}"
    end
  end

  def fetch_share(secid)
    response = HTTP.get("#{BASE_URL}/securities/#{secid}.json?iss.meta=off")

    if response.status.success?
      body = JSON.parse(response.body.to_s)
      description = body["description"]
      columns = description["columns"]
      data = description["data"].map do |row|
        Hash[columns.zip(row)]
      end
      data.map { |row| Hash[row["name"].downcase, row["value"]] }
        .reduce({}, :merge)
        .merge("history_from" => parse_history_from(body))
    else
      raise "Error fetching share: #{response.status} #{response.body.to_s}"
    end
  end

  def fetch_shares_cap_batch
    # https://iss.moex.com/iss/engines/stock/markets/shares/boardgroups/57/securities
    response = HTTP.get("#{BASE_URL}/engines/stock/markets/shares/boardgroups/57/securities.json?iss.meta=off")
    if response.status.success?
      body = JSON.parse(response.body.to_s)
      marketdata = body["marketdata"]
      columns = marketdata["columns"]
      data = marketdata["data"]
      data.map do |row|
        Hash[columns.zip(row)]
      end.map { |row| [row["SECID"], row["ISSUECAPITALIZATION"]] }.to_h
    else
      raise "Error fetching shares: #{response.status} #{response.body.to_s}"
    end
  end

  def fetch_shares_cap
    # https://iss.moex.com/iss/engines/stock/markets/shares/securities/OZON
    Share.where(cap: nil).map do |share|
      response = HTTP.get("#{BASE_URL}/engines/stock/markets/shares/securities/#{share.secid}.json?iss.meta=off")
      if response.status.success?
        body = JSON.parse(response.body.to_s)
        marketdata = body["marketdata"]
        columns = marketdata["columns"]

        cap = marketdata["data"]
          .map { |row| Hash[columns.zip(row)] }
          .map { |row| row["ISSUECAPITALIZATION"] }
          .compact
          .first

        if cap != nil
          puts "Fetched cap for #{share.secid}: #{cap}"
        end

        # share.update!(cap: cap)
      else
        raise "Error fetching share #{share.secid} cap: #{response.status} #{response.body.to_s}"
      end
    end
  end

  private

  def parse_history_from(body)
    boards = body["boards"]
    columns = boards["columns"]
    data = boards["data"]
    data.map { |row| Hash[columns.zip(row)] }
      .map { |row| row["history_from"] }
      .compact
      .min
  end
end

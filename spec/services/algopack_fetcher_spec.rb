require "rails_helper"

describe AlgopackFetcher do
  let(:fetcher) { AlgopackFetcher.instance }

  it "gets shares list" do
    response = fetcher.fetch_shares(offset: 0, limit: 10)
    expect(response).to be_a(Array)
    expect(response.size).to eq(10)
    # p response[0]
  end

  it "gets share details" do
    response = fetcher.fetch_share("ABIO")
    p response
    expect(response).to be_a(Hash)
    expect(response["secid"]).to eq("ABIO")
  end

  it "gets shares cap batch" do
    response = fetcher.fetch_shares_cap_batch
    expect(response).to be_a(Hash)
    expect(response.size).to be > 0
    # p response
  end

  # it "gets shares cap" do
  #   response = fetcher.fetch_shares_cap
  #   expect(response).to be_a(Array)
  #   expect(response.size).to be > 0
  #   # p response
  # end
end

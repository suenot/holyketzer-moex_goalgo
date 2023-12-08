
class CustomIndexesController < ApplicationController
  before_action :authenticate_user!

  protect_from_forgery with: :null_session, only: [:filter_check]

  def index
    @custom_indexes = CustomIndex.all
  end

  def show
    @custom_index = CustomIndex.find(params[:id])
  end

  def new
    date = ShareCap.order(date: :desc).first&.date
    @shares_count = date ? ShareCap.where(date: date).count : 0

    @shares = Share.order(:short_name).pluck(:secid, :short_name)
    @sectors = ShareSector.order(:name).pluck(:id, :name)
    @custom_index = CustomIndex.new
  end

  def filter_check
    listing_levels = params[:listing]&.map(&:to_i)
    sectors = params[:sectors]&.map(&:to_i)
    secids = params[:tickers]

    if (date = ShareCap.order(date: :desc).first&.date)
      filters = {
        IndexCalculator::FILTERS_LL => listing_levels,
        IndexCalculator::FILTERS_SECTOR => sectors,
        IndexCalculator::FILTERS_TICKERS => secids,
      }.compact

      count = IndexCalculator.filter_shares(date, filters).size
      render json: { count: count }
    else
      render json: { error: 'No data available' }
    end
  end

  def create
    @custom_index = CustomIndex.new(custom_index_params)
    # If we index with the same name already exists
    if !@custom_index.save && @custom_index.errors.first&.attribute == :name
      @custom_index.name += " #{SecureRandom.hex(1)}" # make name unique and don't bother user with it
    end

    if @custom_index.save
      BuildIndexJob.perform_async(@custom_index.id)
      redirect_to custom_index_path(@custom_index)
    else
      render :new
    end
  end

  def edit
    @custom_index = CustomIndex.find(params[:id])
  end

  def update
    @custom_index = CustomIndex.find(params[:id])

    if @custom_index.update(custom_index_params)
      redirect_to custom_index_path(@custom_index)
    else
      render :edit
    end
  end

  def destroy
    @custom_index = CustomIndex.find(params[:id])
    @custom_index.destroy

    redireexes custom_indicies_path
  end

  private

  def custom_index_params
    {"review_period"=>"quarterly", "filter_listing"=>["2"], "topcap_count"=>"50", "selection"=>"selection_momentum", "momentum_days"=>"365", "weighing"=>"equal", "index_name"=>"Мой ёлки", "commit"=>"Произвести расчёт"}

    filters = []

    if params[:filter_listing].present?
      filters << [IndexCalculator::FILTERS_LL, params[:filter_listing].map(&:to_i)]
    end

    if params[:filter_sector].present?
      filters << [IndexCalculator::FILTERS_SECTOR, params[:filter_sector].map(&:to_i)]
    end

    if params[:filter_tickers].present?
      filters << [IndexCalculator::FILTERS_TICKERS, params[:filter_tickers]]
    end

    selection = case params[:selection]
    when "selection_topcap"
      [
        IndexCalculator::SELECTION_MARKET_CAP,
        { IndexCalculator::SELECTION_TOP => params[:topcap_count].to_i }
      ]
    when "selection_momentum"
      [
        IndexCalculator::SELECTION_MOMENTUM,
        {
          IndexCalculator::SELECTION_PERIOD => params[:momentum_days].to_i, IndexCalculator::SELECTION_BENCHMARK => "IMOEX"
        }
      ]
    else
      raise "Unknown selection: `#{params[:selection]}`"
    end

    {
      name: params[:index_name],
      settings: {
        IndexCalculator::REVIEW_PERIOD => params[:review_period],
        IndexCalculator::FILTERS => filters,
        IndexCalculator::SELECTION => selection,
        IndexCalculator::WEIGHING => params[:weighing]
      }
    }
  end
end

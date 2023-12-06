
class CustomIndexesController < ApplicationController
  def index
    @custom_indexes = CustomIndex.all
  end

  def show
    @custom_index = CustomIndex.find(params[:id])
  end

  def new
    @custom_index = CustomIndex.new
  end

  def create
    @custom_index = CustomIndex.new(custom_index_params)

    if @custom_index.save
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
    params.require(:custom_index).permit(:name, :description, :value)
  end
end

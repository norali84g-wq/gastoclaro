class Api::V1::CategoriesController < Api::V1::BaseController
  def index
    categories = Category.order(:name)

    render json: categories.map { |category|
      {
        id: category.id,
        name: category.name,
        parent_id: category.parent_id,
        tracks_installments: category.tracks_installments
      }
    }
  end
end

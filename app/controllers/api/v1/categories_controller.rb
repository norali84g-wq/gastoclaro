class Api::V1::CategoriesController < Api::V1::BaseController
  # Las categorías son compartidas por todos los usuarios: solo el admin las crea y las edita.
  before_action :require_admin!, only: %i[create update]
  before_action :set_category, only: :update

  def index
    categories = Category.order(:name)

    render json: categories.map { |category| category_json(category) }
  end

  def create
    category = Category.new(category_params)

    if category.save
      render json: category_json(category), status: :created
    else
      render_record_errors(category)
    end
  end

  def update
    if @category.update(category_params)
      render json: category_json(@category)
    else
      render_record_errors(@category)
    end
  end

  private

  def set_category
    @category = Category.find(params[:id])
  end

  def category_params
    params.permit(:name, :parent_id, :tracks_installments)
  end

  def category_json(category)
    {
      id: category.id,
      name: category.name,
      parent_id: category.parent_id,
      tracks_installments: category.tracks_installments
    }
  end
end

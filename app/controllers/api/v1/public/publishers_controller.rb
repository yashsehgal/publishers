class Api::V1::Public::PublishersController < Api::V1::Public::BaseController
  def totals
    render(json: Publisher.statistical_tools, status: 200)
  end
end

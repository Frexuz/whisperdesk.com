module Tenanted
  class SampleItemsController < ApplicationController
    def show
      item = SampleItem.find(params[:id])
      assert_tenant!(item)
      render json: { id: item.id, name: item.name, tenant_id: item.tenant_id }
    end
  end
end

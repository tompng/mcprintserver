class AreasController < ApplicationController
  before_action :set_area, except: :index
  def index
    @areas = Area.includes(:demo_accounts)
  end

  def teleport
  end

  def add_demo_account
    demo_account = @area.add_demo_account params[:username]
    if demo_account.errors.any?
      redirect_to @area, notice: demo_account.errors.full_messages.join("\n")
    else
      redirect_to @area
    end
  end

  def remove_demo_account
    @area.remove_demo_account params[:username]
    redirect_to @area
  end

  def obj
    if params[:cache].to_s == 'false' || @area.area_cached_obj.nil? || @area.area_cached_obj.updated_at < 10.minutes.ago
      url = "http://localhost:4567/obj?area_id=#{@area.to_param}"
      @area.area_cached_obj ||= AreaCachedObj.new
      @area.area_cached_obj.obj_data = Net::HTTP.get URI.parse(url)
      @area.area_cached_obj.save
    end
    send_data @area.area_cached_obj.obj_data, filename: "block_#{@area.to_param}.obj"
  end

  private

  def set_area
    i, j = params[:i_j].split('_')
    @area = Area.find_by! coord_i: i, coord_j: j
  end
end

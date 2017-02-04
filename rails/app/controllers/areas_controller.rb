class AreasController < ApplicationController
  before_action :set_area, except: [:index, :mcmap, :user_list]
  def index
    @areas = Area.includes(:demo_accounts)
  end

  def teleport
    Mcapi.teleport area_id: @area.to_param, username: params[:username]
    render nothing: true
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

  def user_list
    render json: Area.user_list
  end

  def mcmap
    send_data Mcapi.mcmap, disposition: 'inline', type: 'image/png'
  end

  def obj
    if params[:cache].to_s == 'false' || @area.area_cached_obj.nil? || @area.area_cached_obj.updated_at < 10.minutes.ago
      @area.area_cached_obj ||= AreaCachedObj.new
      @area.area_cached_obj.obj_data = Mcapi.objfile @area.coord_i, @area.coord_j
      @area.area_cached_obj.save
      @area.area_cached_obj.touch
    end
    send_data @area.area_cached_obj.obj_data, filename: "block_#{@area.to_param}.obj"
  end

  private

  def set_area
    i, j = params[:i_j].split('_')
    @area = Area.find_by! coord_i: i, coord_j: j
  end
end

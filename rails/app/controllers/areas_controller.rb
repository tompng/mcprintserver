class AreasController < ApplicationController
  before_action :set_area, except: :index
  def index
    @areas = Area.all
  end

  def teleport
  end

  def add_demo_account
    @area.add_demo_account params[:username]
    redirect_to @area
  end

  def remove_demo_account
    @area.remove_demo_account params[:username]
    redirect_to @area
  end

  private

  def set_area
    i, j = params[:i_j].split('_')
    @area = Area.find_by! coord_i: i, coord_j: j
  end
end

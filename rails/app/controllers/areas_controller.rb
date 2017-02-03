class AreasController < ApplicationController
  before_action :set_area, except: :index
  def index
    @areas = Area.all
  end

  def teleport
  end

  def add
    @area.add_demo_account params[:username]
    redirect_to @area
  end

  def remove
    @area.remove_demo_account params[:username]
    redirect_to @area
  end

  private

  def set_area
    @area = Area.find params[:id]
  end
end

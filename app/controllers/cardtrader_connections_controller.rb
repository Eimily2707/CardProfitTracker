# spec §2.1/§5.7: connecting/disconnecting CardTrader is owner/admin only.
# Personal-token only this tranche - OAuth (§8.10) is spec-deferred.
class CardtraderConnectionsController < ApplicationController
  before_action :set_connection, only: %i[edit update destroy verify]

  def new
    @cardtrader_connection = Current.account.build_cardtrader_connection
    authorize @cardtrader_connection
  end

  def create
    @cardtrader_connection = Current.account.build_cardtrader_connection(connection_params)
    authorize @cardtrader_connection

    if @cardtrader_connection.save
      redirect_to edit_cardtrader_connection_path, notice: t(".success")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @cardtrader_connection.update(connection_params)
      redirect_to edit_cardtrader_connection_path, notice: t(".success")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @cardtrader_connection.disconnect!
    redirect_to root_path, notice: t(".success")
  end

  def verify
    @cardtrader_connection.verify!
    redirect_to edit_cardtrader_connection_path, notice: t(".success")
  rescue Cardtrader::Client::ApiError => e
    redirect_to edit_cardtrader_connection_path, alert: e.message
  end

  private

  def set_connection
    @cardtrader_connection = Current.account.cardtrader_connection
    authorize @cardtrader_connection
  end

  def connection_params
    params.require(:cardtrader_connection).permit(:access_token)
  end
end

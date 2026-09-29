class ChannelsController < ApplicationController
  before_action :set_channel, only: %i[edit update destroy]

  def index
    authorize Channel
    @channels = policy_scope(Channel).order(:name)
  end

  def new
    @channel = Current.account.channels.new(usage: "both")
    authorize @channel
  end

  def create
    @channel = Current.account.channels.new(channel_params)
    authorize @channel

    if @channel.save
      redirect_to channels_path, notice: t(".success")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @channel.update(channel_params)
      redirect_to channels_path, notice: t(".success")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @channel.destroy
      redirect_to channels_path, notice: t(".success"), status: :see_other
    else
      redirect_to channels_path, alert: @channel.errors.full_messages.to_sentence, status: :see_other
    end
  end

  private

  def set_channel
    @channel = Current.account.channels.find(params[:id])
    authorize @channel
  end

  def channel_params
    params.require(:channel).permit(:name, :kind, :usage, :credit_timing, :default_currency, :allows_bundles, :active)
  end
end

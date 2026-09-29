class RegistrationsController < ApplicationController
  allow_unauthenticated_access
  before_action :ensure_registration_enabled

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    @user.locale ||= locale_from_accept_language_header || "en"
    @user.time_zone ||= "UTC"

    ActiveRecord::Base.transaction do
      @user.save!

      account = Account.new(account_params)
      account.default_locale = @user.locale
      account.time_zone = @user.time_zone
      account.save!

      Membership.create!(account: account, user: @user, role: "owner")
    end

    start_new_session_for(@user)
    redirect_to root_path, notice: t(".success")
  rescue ActiveRecord::RecordInvalid => e
    flash.now[:alert] = e.record.errors.full_messages.to_sentence
    render :new, status: :unprocessable_entity
  end

  private

  def ensure_registration_enabled
    return if Rails.application.config.x.public_registration_enabled

    redirect_to new_session_path, alert: t("registrations.disabled")
  end

  def user_params
    params.require(:user).permit(:email, :password, :name)
  end

  def account_params
    params.require(:account).permit(:name, :country)
  end
end

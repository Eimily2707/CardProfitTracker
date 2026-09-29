class AccountSwitchesController < ApplicationController
  def create
    membership = Current.user.memberships.find_by(account_id: params[:account_id])

    if membership
      cookies[:current_account_id] = { value: membership.account_id, httponly: true, same_site: :lax }
      Current.account = membership.account
    end

    redirect_back fallback_location: root_path
  end
end

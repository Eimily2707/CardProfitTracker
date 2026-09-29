class InvitationsController < ApplicationController
  # allow_unauthenticated_access skips require_authentication entirely, which
  # is also the only thing that calls resume_session - so without this,
  # Current.user would stay nil here even for an actually signed-in visitor.
  # accept specifically needs to know whether to join with the existing
  # user or offer to create one.
  allow_unauthenticated_access only: %i[show accept]
  before_action :resume_session, only: %i[show accept]

  before_action :set_invitation_by_token, only: %i[show accept]
  before_action :set_invitation, only: :destroy

  def index
    authorize Invitation
    @invitations = policy_scope(Invitation).where(accepted_at: nil).order(created_at: :desc)
  end

  def new
    @invitation = Current.account.invitations.new
    authorize @invitation
  end

  def create
    @invitation = Current.account.invitations.new(invitation_params)
    @invitation.invited_by = Current.user
    authorize @invitation

    if @invitation.save
      InvitationMailer.invite(@invitation, @invitation.token).deliver_later
      redirect_to invitations_path, notice: t(".success")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @invitation
    @invitation.destroy
    redirect_to invitations_path, notice: t(".success"), status: :see_other
  end

  # GET /invitations/:token - public preview + accept form
  def show
  end

  # POST /invitations/:token/accept - public
  def accept
    if Current.user
      accept_for_existing_user!
    else
      accept_with_new_user!
    end
  end

  private

  def accept_for_existing_user!
    unless Current.user.memberships.exists?(account: @invitation.account)
      Membership.create!(account: @invitation.account, user: Current.user, role: @invitation.role)
    end

    @invitation.accept!
    redirect_to root_path, notice: t(".success", account: @invitation.account.name)
  end

  def accept_with_new_user!
    # email is the invited address, not editable - the invitation is for
    # that specific person, not whoever happens to have the link.
    user = User.new(user_params)
    user.email = @invitation.email
    user.locale ||= locale_from_accept_language_header || "en"
    user.time_zone ||= "UTC"

    ActiveRecord::Base.transaction do
      user.save!
      Membership.create!(account: @invitation.account, user: user, role: @invitation.role)
      @invitation.accept!
    end

    start_new_session_for(user)
    redirect_to root_path, notice: t(".success", account: @invitation.account.name)
  rescue ActiveRecord::RecordInvalid => e
    flash.now[:alert] = e.record.errors.full_messages.to_sentence
    render :show, status: :unprocessable_entity
  end

  def set_invitation_by_token
    @invitation = Invitation.find_by_token(params[:token])

    if @invitation.nil?
      redirect_to new_session_path, alert: t("invitations.accept.not_found")
    elsif @invitation.accepted?
      redirect_to new_session_path, alert: t("invitations.accept.already_accepted")
    elsif @invitation.expired?
      redirect_to new_session_path, alert: t("invitations.accept.expired")
    end
  end

  def set_invitation
    @invitation = Invitation.find(params[:id])
  end

  def invitation_params
    params.require(:invitation).permit(:email, :role)
  end

  def user_params
    params.require(:user).permit(:name, :password)
  end
end

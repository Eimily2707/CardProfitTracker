class InvitationMailer < ApplicationMailer
  # token is passed explicitly (not re-read from invitation.token) because
  # the raw token only exists transiently in memory at creation time -
  # deliver_later re-serializes the Invitation as a GlobalID and reloads it
  # in the job, which would lose it.
  def invite(invitation, token)
    @invitation = invitation
    @token = token

    I18n.with_locale(invitation.account.default_locale || I18n.default_locale) do
      mail to: invitation.email, subject: t(".subject", account: invitation.account.name)
    end
  end
end

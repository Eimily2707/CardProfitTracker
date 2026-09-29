class ApplicationController < ActionController::Base
  include Authentication
  include Pundit::Authorization

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  rescue_from Pundit::NotAuthorizedError, with: :render_forbidden

  # Registered after Authentication's before_action, so Current.user is
  # already resolved by the time this runs (spec §2.2: users.locale ->
  # Accept-Language -> en).
  around_action :switch_locale

  # Attributes PaperTrail versions (spec §2.4) to the signed-in user.
  before_action { PaperTrail.request.whodunnit = Current.user&.id }

  private

  # Rails 8 authentication exposes the signed-in user as Current.user, not a
  # current_user controller method, so Pundit needs to be told where to find it.
  def pundit_user
    Current.user
  end

  def switch_locale(&action)
    I18n.with_locale(determine_locale, &action)
  end

  def determine_locale
    Current.user&.locale || locale_from_accept_language_header || I18n.default_locale
  end

  def locale_from_accept_language_header
    candidate = request.env["HTTP_ACCEPT_LANGUAGE"].to_s.scan(/[a-zA-Z]{2}/).first&.downcase
    candidate if candidate && I18n.available_locales.map(&:to_s).include?(candidate)
  end

  def render_forbidden
    respond_to do |format|
      format.html { redirect_back fallback_location: root_path, alert: t("pundit.not_authorized", default: "Non sei autorizzato a farlo.") }
      format.json { head :forbidden }
    end
  end
end

# Lets a signed-in user change their own display language (spec §12
# "Localizzazione") - previously only set at registration/invitation time,
# with no way to change it afterward.
class LocalesController < ApplicationController
  def update
    Current.user.update!(locale: params[:locale]) if User::SUPPORTED_LOCALES.include?(params[:locale])

    redirect_back fallback_location: root_path
  end
end

module ApplicationHelper
  # Single source of truth for the header nav (desktop row + mobile panel
  # render the same list - spec §12 "Responsive... 375 px").
  def main_nav_links
    links = [
      [ t("catalog.index.title"), catalog_path ],
      [ t("purchases.index.title"), purchases_path ],
      [ t("inventory_items.index.title"), inventory_items_path ],
      [ t("sales.index.title"), sales_path ],
      [ t("channels.index.title"), channels_path ],
      [ t("tasks.index.title"), tasks_path ]
    ]

    if Current.membership&.admin? || Current.membership&.owner?
      links << [ t("invitations.index.title"), invitations_path ]
      links << [ t("cardtrader_connections.nav_title"),
                 Current.account&.cardtrader_connection ? edit_cardtrader_connection_path : new_cardtrader_connection_path ]
    end

    links
  end

  LOCALE_NAMES = { "it" => "Italiano", "en" => "English", "fr" => "Français", "es" => "Español", "de" => "Deutsch" }.freeze
end

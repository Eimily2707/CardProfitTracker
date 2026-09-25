namespace :cardtrader do
  desc "Sincronizza il catalogo blueprint di CardTrader nel DB locale (opzionale: GAME_ID=1 per limitare a un gioco)"
  task sync_blueprints: :environment do
    game_id = ENV["GAME_ID"].presence

    puts "Avvio sincronizzazione blueprint CardTrader#{" (game_id=#{game_id})" if game_id}..."
    count = Cardtrader::BlueprintSync.new(game_id: game_id).call
    puts "Completato: #{count} blueprint sincronizzati."
  end
end

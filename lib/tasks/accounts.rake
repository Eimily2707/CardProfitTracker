namespace :accounts do
  desc "Crea il primo account e il suo owner (fase personale: registrazione pubblica disattivata, §2.1). " \
       "Uso: bin/rails accounts:setup EMAIL=... PASSWORD=... ACCOUNT_NAME=... [COUNTRY=IT] [LOCALE=it] [TIME_ZONE=Europe/Rome]"
  task setup: :environment do
    email = ENV.fetch("EMAIL") { abort "EMAIL è obbligatorio" }
    password = ENV.fetch("PASSWORD") { abort "PASSWORD è obbligatorio" }
    account_name = ENV.fetch("ACCOUNT_NAME") { abort "ACCOUNT_NAME è obbligatorio" }
    country = ENV.fetch("COUNTRY", "IT")
    locale = ENV.fetch("LOCALE", "it")
    time_zone = ENV.fetch("TIME_ZONE", "UTC")

    ActiveRecord::Base.transaction do
      user = User.create!(
        email: email, password: password,
        locale: locale, time_zone: time_zone, confirmed_at: Time.current
      )
      account = Account.create!(name: account_name, country: country, time_zone: time_zone, default_locale: locale)
      Membership.create!(account: account, user: user, role: "owner")

      puts "Creato account '#{account.name}' (##{account.id}) con owner #{user.email}."
    end
  rescue ActiveRecord::RecordInvalid => e
    abort "Errore: #{e.message}"
  end
end

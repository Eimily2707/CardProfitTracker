# Replaces Rails' default /up (which only proves the app booted) with an
# operational check a load balancer/uptime monitor can actually act on:
# can it reach Postgres, and is a Solid Queue worker alive to process
# webhooks/order syncs (spec §8.7/§9.1). No auth - must stay reachable with
# no session, same as the endpoint it replaces.
class HealthController < ActionController::Base
  def show
    failures = []
    failures << "database" unless database_healthy?
    failures << "queue" unless queue_healthy?

    if failures.empty?
      render html: helpers.tag.p("OK"), layout: false
    else
      render html: helpers.tag.p("FAIL: #{failures.join(', ')}"), layout: false, status: :internal_server_error
    end
  end

  private

  def database_healthy?
    ActiveRecord::Base.connection.active?
  rescue StandardError
    false
  end

  # SOLID_QUEUE_IN_PUMA runs the dispatcher/worker in-process in production
  # (config/deploy.yml) - a process with no heartbeat in the last 2 minutes
  # means jobs (webhook sync, marketplace import) have silently stopped.
  def queue_healthy?
    SolidQueue::Process.where(last_heartbeat_at: 2.minutes.ago..).exists?
  rescue StandardError
    false
  end
end

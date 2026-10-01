# spec §4.15/§5.11 ("Da sistemare"): the in-app notification list. Tasks
# are opened/resolved only by service objects; a person can just snooze,
# reopen, or dismiss one.
class TasksController < ApplicationController
  before_action :set_task, only: %i[snooze dismiss unsnooze]

  def index
    authorize Task
    @tasks = policy_scope(Task).open_or_snoozed.order(priority: :asc, created_at: :desc)
  end

  def snooze
    @task.snooze!(1.week.from_now)
    redirect_to tasks_path, notice: t(".success")
  end

  def dismiss
    @task.dismiss!(params[:reason])
    redirect_to tasks_path, notice: t(".success")
  end

  def unsnooze
    @task.unsnooze!
    redirect_to tasks_path, notice: t(".success")
  end

  private

  def set_task
    @task = Current.account.tasks.find(params[:id])
    authorize @task, :update?
  end
end

module Expenses
  class GenerateRecurringDraftsJob < ApplicationJob
    queue_as :default

    def perform
      Expenses::GenerateRecurringDraftsService.call!
    end
  end
end

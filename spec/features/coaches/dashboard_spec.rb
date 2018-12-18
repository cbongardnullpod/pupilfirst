require 'rails_helper'

feature 'Coach Dashboard' do
  include UserSpecHelper

  # Setup a coach and 2 startups for him...
  let(:course) { create :course }
  let(:level_0) { create :level, :zero, course: course }
  let(:coach) { create :faculty }
  let!(:startup_1) { create :startup, level: level_0 }
  let!(:startup_2) { create :startup, level: level_0 }
  let(:track) { create :track, name: 'Some track' }
  let(:target_group) { create :target_group, level: level_0, track: track }
  let!(:target) { create :target, target_group: target_group, submittability: Target::SUBMITTABILITY_AUTO_VERIFY }

  # ... and create a couple of pending timeline events for her startup.
  let!(:timeline_event_1) { create(:timeline_event, startup: startup_1) }
  let!(:timeline_event_2) { create(:timeline_event, startup: startup_1) }
  let!(:timeline_event_3) { create(:timeline_event, startup: startup_2) }
  let!(:timeline_event_4) { create(:timeline_event, startup: startup_2) }
  let!(:auto_verified_event) { create(:timeline_event, startup: startup_1, target: target) }

  before do
    create :faculty_course_enrollment, faculty: coach, course: course
  end

  scenario 'coach visits dashboard', js: true do
    sign_in_user coach.user, referer: coaches_dashboard_path

    # ensure coach is on his dashboard
    expect(page).to have_selector('.side-panel__coach-name', text: coach.name)
    expect(page).to have_selector('.side-panel__coach-description', text: 'Pending reviews: 4')

    # and his startups are listed properly on the sidebar
    within('.startups-list__container') do
      expect(page).to have_selector('.startups-list__item', count: 2)
      expect(page).to have_selector('.startups-list__item-name', text: startup_1.product_name)
      expect(page).to have_selector('.startups-list__item-name', text: startup_2.product_name)
    end

    # and all the timeline events are listed (excluding the auto-verified one)
    within('.timeline-events-list__container') do
      expect(page).to have_selector('.timeline-event-card__container', count: 4)
    end

    # and the 'complete' list is empty
    expect(page).to have_selector('.timeline-events-panel__empty-notice', text: 'Nothing to show!')
  end

  scenario 'coach uses the sidebar filter', js: true do
    sign_in_user coach.user, referer: coaches_dashboard_path

    # no filter applied by default
    expect(page).to_not have_selector('.startups-list__clear-filter-btn')
    find('.startups-list__item-name', text: startup_1.product_name).click
    # the list should now be filtered correctly
    expect(page).to have_selector('.timeline-event-card__container', count: 2)
    expect(page).to have_selector('.timeline-event-card__header-title', text: timeline_event_1.title)
    expect(page).to have_selector('.timeline-event-card__header-title', text: timeline_event_2.title)
    expect(page).to_not have_selector('.timeline-event-card__header-title', text: timeline_event_3.title)
    expect(page).to_not have_selector('.timeline-event-card__header-title', text: timeline_event_4.title)

    # and the clear filter button visible
    expect(page).to have_selector('.startups-list__clear-filter-btn')

    # clearing the filter should display all events again
    click_on 'Show All'
    expect(page).to have_selector('.timeline-event-card__container', count: 4)
  end

  scenario 'coach reviews all timeline events', js: true do
    sign_in_user coach.user, referer: coaches_dashboard_path

    # mark the first event as not accepted
    within(".js-timeline-event-card__review-box-#{timeline_event_1.id}") do
      find("#review-form__status-input-not-accepted-#{timeline_event_1.id}").click
      click_on 'Save Review'
    end

    # the event should have moved to the completed list
    within all('.timeline-events-list__container').first do
      expect(page).to have_selector('.timeline-event-card__container', count: 3)
    end
    # and the pending count updated
    expect(page).to have_selector('.side-panel__coach-description', text: 'Pending reviews: 3')

    within all('.timeline-events-list__container').last do
      expect(page).to have_selector('.timeline-event-card__header-title', text: timeline_event_1.title)

      # and should include the new status badge
      expect(page).to have_selector('.review-status-badge__container--not-accepted')
      # the event should have the new status
      expect(timeline_event_1.reload.status).to eq(TimelineEvent::STATUS_NOT_ACCEPTED)

      # undo the review
      click_on 'Undo Review'
    end

    # the event should have moved back to the pending list
    within all('.timeline-events-list__container').first do
      expect(page).to have_selector('.timeline-event-card__container', count: 4)
    end
    expect(page).to have_selector('.timeline-events-panel__empty-notice', text: 'Nothing to show!')
    expect(timeline_event_1.reload.status).to eq(TimelineEvent::STATUS_PENDING)

    # and the pending count updated
    expect(page).to have_selector('.side-panel__coach-description', text: 'Pending reviews: 4')

    # now mark the event as verified with a grade
    within(".js-timeline-event-card__review-box-#{timeline_event_1.id}") do
      # grade from should be hidden
      expect(page).to_not have_selector('.js-review-form__grade-radios')
      find("#review-form__status-input-verified-#{timeline_event_1.id}").click
      # grade form should now be visible
      expect(page).to have_selector('.js-review-form__grade-radios')
      find("#review-form__grade-input-great-#{timeline_event_1.id}").click
      click_on 'Save Review'
    end

    # the event should have moved to the completed list
    within all('.timeline-events-list__container').first do
      expect(page).to have_selector('.timeline-event-card__container', count: 3)
    end
    within all('.timeline-events-list__container').last do
      expect(page).to have_selector('.timeline-event-card__header-title', text: timeline_event_1.title)

      # and should include the new status badge
      expect(page).to have_selector('.review-status-badge__container--verified')
      # the event should have the new status and grade
      expect(timeline_event_1.reload.status).to eq(TimelineEvent::STATUS_VERIFIED)
      expect(timeline_event_1.overall_grade_from_score).to eq('great')
    end

    # mark the remaining three as needs improvement
    within(".js-timeline-event-card__review-box-#{timeline_event_2.id}") do
      find("#review-form__status-input-needs-improvement-#{timeline_event_2.id}").click
      click_on 'Save Review'
    end
    within(".js-timeline-event-card__review-box-#{timeline_event_3.id}") do
      find("#review-form__status-input-needs-improvement-#{timeline_event_3.id}").click
      click_on 'Save Review'
    end
    within(".js-timeline-event-card__review-box-#{timeline_event_4.id}") do
      find("#review-form__status-input-needs-improvement-#{timeline_event_4.id}").click
      click_on 'Save Review'
    end

    # the pending list should now be empty
    expect(page).to have_selector('.timeline-events-panel__empty-notice', text: 'Nothing pending here!')
    # and the completed list should have the right status badges
    within('.timeline-events-list__container') do
      expect(page).to have_selector('.timeline-event-card__container', count: 4)
      expect(page).to have_selector('.review-status-badge__container--verified', count: 1)
      expect(page).to have_selector('.review-status-badge__container--needs-improvement', count: 3)
    end
    # and the pending count should have updated
    expect(page).to have_selector('.side-panel__coach-description', text: 'Pending reviews: 0')
  end

  scenario 'coach add a feedback', js: true do
    sign_in_user coach.user, referer: coaches_dashboard_path

    within find(".timeline-event-card__container", match: :first) do
      # feedback form should be hidden by default
      expect(page).to_not have_selector('.feedback-form__trix-container')
      click_on 'Email Feedback'
      # the form should now be visible
      expect(page).to have_selector('.feedback-form__trix-container')
      click_on 'Cancel'
      # form hidden again
      expect(page).to_not have_selector('.feedback-form__trix-container')
      # Let's add a feedback
      click_on 'Email Feedback'
      find('trix-editor').click.set 'Some important feedback'
      click_on 'Send'
      # form should now be hidden
      expect(page).to_not have_selector('.feedback-form__trix-container')
      # and a feedback created for the event
      expect(StartupFeedback.last.feedback).to eq('<div>Some important feedback</div>')
    end
  end
end

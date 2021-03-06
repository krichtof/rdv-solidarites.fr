describe UpdatePlageOuverturesExpirationsJob, type: :job do
  let!(:plage_ouverture_reguliere) { create(:plage_ouverture, recurrence: Montrose.every(:week, until: Time.now)) }
  let!(:plage_ouverture_exceptionnelle) { create(:plage_ouverture, :no_recurrence, first_day: Date.today) }

  subject do
    UpdatePlageOuverturesExpirationsJob.perform_now
  end

  context "when plage ouverture are expired" do
    it "should call notification service" do
      travel_to(2.days.from_now)
      expect { subject }.to change(PlageOuverture.where(expired_cached: true), :count).from(0).to(2)
    end
  end

  context "when plage ouverture are not expired" do
    it "should call notification service" do
      expect { subject }.not_to change(PlageOuverture.where(expired_cached: true), :count)
    end
  end
end

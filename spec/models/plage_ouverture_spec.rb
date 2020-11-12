describe PlageOuverture, type: :model do
  let!(:organisation) { create(:organisation) }

  describe "#end_after_start" do
    let(:plage_ouverture) { build(:plage_ouverture, start_time: start_time, end_time: end_time, organisation: organisation) }

    context "start_time < end_time" do
      let(:start_time) { Tod::TimeOfDay.new(7) }
      let(:end_time) { Tod::TimeOfDay.new(8) }

      it { expect(plage_ouverture.send(:end_after_start)).to be_nil }
    end

    context "start_time = end_time" do
      let(:start_time) { Tod::TimeOfDay.new(7) }
      let(:end_time) { start_time }

      it { expect(plage_ouverture.send(:end_after_start)).to eq(["doit être après l'heure de début"]) }
    end

    context "start_time > end_time" do
      let(:start_time) { Tod::TimeOfDay.new(7, 30) }
      let(:end_time) { Tod::TimeOfDay.new(7) }

      it { expect(plage_ouverture.send(:end_after_start)).to eq(["doit être après l'heure de début"]) }
    end
  end

  require Rails.root.join "spec/models/concerns/recurrence_concern_spec.rb"
  it_behaves_like "recurrence"

  describe ".for_motif_and_lieu_from_date_range" do
    let!(:service) { create(:service, name: "pmi") }
    let!(:motif) { create(:motif, name: "Vaccination", default_duration_in_min: 30, service: service, organisation: organisation) }
    let!(:lieu) { create(:lieu, organisation: organisation) }
    let(:today) { Date.new(2019, 9, 19) }
    let(:six_days_later) { Date.new(2019, 9, 25) }
    let(:agent) { create(:agent, service: service, organisations: [organisation]) }
    let(:agent2) { create(:agent, service: service, organisations: [organisation]) }
    let(:agent3) { create(:agent, service: service, organisations: [organisation]) }
    let!(:plage_ouverture) { create(:plage_ouverture, :weekly, agent: agent, motifs: [motif], lieu: lieu, first_day: today, start_time: Tod::TimeOfDay.new(9), end_time: Tod::TimeOfDay.new(11), organisation: organisation) }

    subject { PlageOuverture.for_motif_and_lieu_from_date_range(motif.name, lieu, today..six_days_later) }

    it { expect(subject).to contain_exactly(plage_ouverture) }

    describe "when first_day is the last day of time range" do
      let!(:plage_ouverture) { create(:plage_ouverture, :weekly, motifs: [motif], lieu: lieu, first_day: six_days_later, start_time: Tod::TimeOfDay.new(9), end_time: Tod::TimeOfDay.new(11), organisation: organisation) }

      it { expect(subject).to contain_exactly(plage_ouverture) }
    end

    describe "when first_day is before time range" do
      let!(:plage_ouverture) { create(:plage_ouverture, :weekly, motifs: [motif], lieu: lieu, first_day: today - 2.days, start_time: Tod::TimeOfDay.new(9), end_time: Tod::TimeOfDay.new(11), organisation: organisation) }

      it { expect(subject).to contain_exactly(plage_ouverture) }
    end

    describe "when first_day is after time range" do
      let!(:plage_ouverture) { create(:plage_ouverture, :weekly, motifs: [motif], lieu: lieu, first_day: today + 8.days, start_time: Tod::TimeOfDay.new(9), end_time: Tod::TimeOfDay.new(11), organisation: organisation) }

      it { expect(subject.count).to eq(0) }
    end
  end

  describe "#expired?" do
    subject { plage_ouverture.expired? }

    context "with exceptionnelles plages" do
      describe "when first_day is in past" do
        let(:plage_ouverture) { create(:plage_ouverture, :no_recurrence, first_day: Date.parse("2020-07-30"), organisation: organisation) }

        it { should be true }
      end

      describe "when first_day is in future" do
        let(:plage_ouverture) { create(:plage_ouverture, :no_recurrence, first_day: 2.days.from_now, organisation: organisation) }

        it { should be false }
      end

      describe "when first_day is today" do
        let(:plage_ouverture) { create(:plage_ouverture, :no_recurrence, first_day: Date.today, organisation: organisation) }

        it { should be false }
      end
    end

    context "with plages regulières" do
      describe "when until is in past" do
        let(:plage_ouverture) { create(:plage_ouverture, recurrence: Montrose.every(:week, until: DateTime.parse("2020-07-30 10:30").in_time_zone).to_json, organisation: organisation) }

        it { should be true }
      end

      describe "when until is in future" do
        let(:plage_ouverture) { create(:plage_ouverture, recurrence: Montrose.every(:week, until: 2.days.from_now).to_json, organisation: organisation) }

        it { should be false }
      end

      describe "when until is today" do
        let(:plage_ouverture) { create(:plage_ouverture, recurrence: Montrose.every(:week, until: Date.today).to_json, organisation: organisation) }

        it { should be false }
      end
    end
  end

  describe "#available_motifs" do
    let!(:orga2) { create(:organisation) }
    let!(:service) { create(:service) }
    let!(:motif) { create(:motif, name: "Accueil", service: service, organisation: organisation) }
    let!(:motif2) { create(:motif, name: "Suivi", service: service, organisation: organisation) }
    let!(:motif3) { create(:motif, :for_secretariat, name: "Test", service: service, organisation: organisation) }
    let!(:motif4) { create(:motif, name: "other orga", service: service, organisation: orga2) }
    let(:plage_ouverture) { build(:plage_ouverture, agent: agent, organisation: organisation, motifs: [motif]) }

    subject { plage_ouverture.available_motifs }

    describe "for secretaire" do
      let(:agent) { create(:agent, :secretaire, organisations: [organisation]) }

      it { is_expected.to contain_exactly(motif3) }
    end

    describe "for other service" do
      let(:agent) { create(:agent, service: service, organisations: [organisation]) }

      it { is_expected.to contain_exactly(motif, motif2, motif3) }
    end
  end

  describe "#notify_agent_plage_ouverture_created" do
    let(:plage_ouverture) { build(:plage_ouverture, organisation: organisation) }

    it "should be called after create" do
      expect(plage_ouverture).to receive(:notify_agent_plage_ouverture_created)
      plage_ouverture.save!
    end

    context "when rdv already exist" do
      let(:plage_ouverture) { create(:plage_ouverture, organisation: organisation) }

      it "should not be called" do
        expect(plage_ouverture).not_to receive(:notify_agent_plage_ouverture_created)
        plage_ouverture.save!
      end
    end

    it "calls Agents::PlageOuvertureMailer to send email to agetn" do
      expect(Agents::PlageOuvertureMailer).to receive(:plage_ouverture_created).with(plage_ouverture).and_return(double(deliver_later: nil))
      plage_ouverture.save!
    end
  end

  describe "#overlaps?" do
    let(:monday) { Time.parse("2020-11-09") }

    before { plage_ouverture_1.overlaps?(plage_ouverture_2) == plage_ouverture_2.overlaps?(plage_ouverture_1) }
    subject { plage_ouverture_1.overlaps?(plage_ouverture_2) }

    context "both exceptionnelles" do
      let(:plage_ouverture_1) { build(:plage_ouverture, first_day: monday, start_time: Tod::TimeOfDay.new(14), end_time: Tod::TimeOfDay.new(18)) }

      context "exactly overlapping" do
        let(:plage_ouverture_2) { build(:plage_ouverture, first_day: monday, start_time: Tod::TimeOfDay.new(14), end_time: Tod::TimeOfDay.new(18)) }
        it { should eq true }
      end

      context "included in other" do
        let(:plage_ouverture_2) { build(:plage_ouverture, first_day: monday, start_time: Tod::TimeOfDay.new(15), end_time: Tod::TimeOfDay.new(16)) }
        it { should eq true }
      end

      context "includes other" do
        let(:plage_ouverture_2) { build(:plage_ouverture, first_day: monday, start_time: Tod::TimeOfDay.new(8), end_time: Tod::TimeOfDay.new(20)) }
        it { should eq true }
      end

      context "partially overlapping start" do
        let(:plage_ouverture_2) { build(:plage_ouverture, first_day: monday, start_time: Tod::TimeOfDay.new(8), end_time: Tod::TimeOfDay.new(16)) }
        it { should eq true }
      end

      context "partially overlapping end" do
        let(:plage_ouverture_2) { build(:plage_ouverture, first_day: monday, start_time: Tod::TimeOfDay.new(16), end_time: Tod::TimeOfDay.new(20)) }
        it { should eq true }
      end

      context "non overlapping same day" do
        let(:plage_ouverture_2) { build(:plage_ouverture, first_day: monday, start_time: Tod::TimeOfDay.new(8), end_time: Tod::TimeOfDay.new(12)) }
        it { should eq false }
      end

      context "non overlapping other day" do
        let(:plage_ouverture_2) { build(:plage_ouverture, first_day: monday + 1.day, start_time: Tod::TimeOfDay.new(14), end_time: Tod::TimeOfDay.new(18)) }
        it { should eq false }
      end
    end

    context "one recurring without end date, one exceptionnelle" do
      let(:plage_ouverture_1) { build(:plage_ouverture, first_day: monday, start_time: Tod::TimeOfDay.new(14), end_time: Tod::TimeOfDay.new(18), recurrence: Montrose.weekly.on([:monday, :tuesday]).to_json) }

      context "exceptionnelle before recurring" do
        let(:plage_ouverture_2) { build(:plage_ouverture, first_day: monday - 7.days, start_time: Tod::TimeOfDay.new(14), end_time: Tod::TimeOfDay.new(18)) }
        it { should eq false }
      end

      context "exceptionnelle on other day same week" do
        let(:plage_ouverture_2) { build(:plage_ouverture, first_day: monday + 3.days, start_time: Tod::TimeOfDay.new(14), end_time: Tod::TimeOfDay.new(18)) }
        it { should eq false }
      end

      context "exceptionnelle on other day next week" do
        let(:plage_ouverture_2) { build(:plage_ouverture, first_day: monday + 3.days, start_time: Tod::TimeOfDay.new(14), end_time: Tod::TimeOfDay.new(18)) }
        it { should eq false }
      end

      context "exceptionnelle on same day but times don't overlap" do
        let(:plage_ouverture_2) { build(:plage_ouverture, first_day: monday + 8.days, start_time: Tod::TimeOfDay.new(8), end_time: Tod::TimeOfDay.new(10)) }
        it { should eq false }
      end

      context "exceptionnelle on same day and times overlap" do
        let(:plage_ouverture_2) { build(:plage_ouverture, first_day: monday + 8.days, start_time: Tod::TimeOfDay.new(15), end_time: Tod::TimeOfDay.new(20)) }
        it { should eq true }
      end
    end

    context "one recurring every 3 weeks without end date, one exceptionnelle" do
      let(:plage_ouverture_1) { build(:plage_ouverture, first_day: monday, start_time: Tod::TimeOfDay.new(14), end_time: Tod::TimeOfDay.new(18), recurrence: Montrose.every(3.weeks).on([:monday, :tuesday]).to_json) }

      context "exceptionnelle on same week day 6 weeks after" do
        let(:plage_ouverture_2) { build(:plage_ouverture, first_day: monday + (7 * 6).days, start_time: Tod::TimeOfDay.new(14), end_time: Tod::TimeOfDay.new(18)) }
        it { should eq true }
      end

      context "exceptionnelle on same week day 4 weeks after" do
        let(:plage_ouverture_2) { build(:plage_ouverture, first_day: monday + (7 * 4).days, start_time: Tod::TimeOfDay.new(14), end_time: Tod::TimeOfDay.new(18)) }
        it { should eq false }
      end
    end
  end
end

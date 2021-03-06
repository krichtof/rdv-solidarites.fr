describe "Agent can CRUD plage d'ouverture" do
  let!(:organisation) { create(:organisation) }
  let!(:service) { create(:service, name: "PMI") }
  let!(:motif) { create(:motif, name: "Suivi bonjour", service: service, organisation: organisation) }
  let!(:agent) { create(:agent, :admin, service: service, organisations: [organisation]) }
  let!(:lieu) { create(:lieu, organisation: organisation) }
  let!(:plage_ouverture) { create(:plage_ouverture, motifs: [motif], lieu: lieu, agent: agent, organisation: organisation) }
  let(:new_plage_ouverture) { build(:plage_ouverture, lieu: lieu, agent: agent, organisation: organisation) }

  before do
    login_as(agent, scope: :agent)
    visit authenticated_agent_root_path
    click_link "Plages d'ouverture"
  end

  shared_examples "can crud own plage ouvertures" do
    it "works" do
      expect_page_title("Vos plages d'ouverture")
      click_link plage_ouverture.title

      expect_page_title("Modifier votre plage d'ouverture")
      fill_in "Description", with: "La belle plage"
      click_button("Modifier")

      expect_page_title("Modifier votre plage d'ouverture")
      expect(page).to have_content("La belle plage")

      click_link("Supprimer")
      expect_page_title("Vos plages d'ouverture")
      expect(page).to have_content("Vous n'avez pas encore créé de plage d'ouverture")

      click_link "Créer une plage d'ouverture", match: :first

      expect_page_title("Nouvelle plage d'ouverture")
      fill_in "Description", with: new_plage_ouverture.title
      check "Suivi bonjour"
      click_button "Créer"

      expect_page_title("Vos plages d'ouverture")
      click_link new_plage_ouverture.title
    end
  end

  context "for an agent" do
    it_behaves_like "can crud own plage ouvertures"
  end

  context "for a secretaire" do
    let(:agent) { create(:agent, :secretaire, organisations: [organisation]) }

    scenario "cannot create plage_ouverture" do
      expect_page_title("Vos plages d'ouverture")
      click_link "Créer une plage d'ouverture", match: :first
      expect(page).to have_content("Aucun motif disponible. Vous ne pouvez pas créer de plage d'ouverture.")
    end

    context "with motif for_secretariat" do
      let!(:motif) { create(:motif, :for_secretariat, name: "Suivi bonjour", service: service, organisation: organisation) }
      let(:plage_ouverture) { create(:plage_ouverture, lieu: lieu, agent: agent, motifs: [motif], organisation: organisation) }
      it_behaves_like "can crud own plage ouvertures"
    end
  end

  context "for an other agent calendar" do
    let!(:other_agent) { create(:agent, first_name: "Jane", last_name: "FAROU", service: service, organisations: [organisation]) }
    let!(:plage_ouverture) { create(:plage_ouverture, lieu: lieu, agent: other_agent, organisation: organisation) }

    scenario "can crud a plage_ouverture" do
      visit admin_organisation_agent_plage_ouvertures_path(organisation, other_agent.id)

      expect_page_title("Plages d'ouverture de Jane FAROU (PMI)")
      click_link plage_ouverture.title

      expect_page_title("Modifier la plage d'ouverture de Jane FAROU")
      fill_in "Description", with: "La belle plage"
      click_button("Modifier")

      expect_page_title("Modifier la plage d'ouverture de Jane FAROU")
      expect(page).to have_content("La belle plage")

      click_link("Supprimer")
      expect_page_title("Plages d'ouverture de Jane FAROU (PMI)")
      expect(page).to have_content("Jane FAROU n'a pas encore créé de plage d'ouverture")

      click_link "Créer une plage d'ouverture pour Jane FAROU", match: :first

      expect_page_title("Nouvelle plage d'ouverture")
      fill_in "Description", with: new_plage_ouverture.title
      check "Suivi bonjour"
      click_button "Créer"

      expect_page_title("Plages d'ouverture de Jane FAROU (PMI)")
      click_link new_plage_ouverture.title
    end
  end
end

class Admins::OrganisationMailer < ApplicationMailer
  def organisation_created(agent, organisation)
    @agent = agent
    @organisation = organisation
    mail(to: "contact@rdv-solidarites.fr", subject: "Nouvelle organisation créée - #{@organisation.departement} - #{@organisation.name}")
  end
end

class YearEndClosing
  include ActiveModel::Validations
  include ActiveModel::Conversion
  extend ActiveModel::Naming

  attr_accessor :year

  validates :year, presence: true
  validates :year, :numericality => true

  def initialize(attributes = {})
    @year = attributes[:year] || Time.now.prev_year.year
    @year = @year.to_i #TODO fix this on controller side with strong params?
  end


  def close_year!
    Contract.where(:add_interest_to_deposit_annually => true).all.each do |contract|
      close_year_for_contract(contract)
    end
  end

  def close_year_for_contract(contract)
    return false if contract.start_date.year > @year
    return false if year_closed?(contract)
    return false if contract.terminated_at.present?
    last_years_interest = InterestCalculation.new(contract, year: @year).interest_total
    contract.accounting_entries.create!(amount: last_years_interest, date: Date.new(@year).end_of_year,
                                        annually_closing_entry: true, interest_entry: true)
  end

  def year_closed?(contract)
    closing_entry_for_this_year = contract.accounting_entries.only_from_year(@year).where(annually_closing_entry: true)
    return false if closing_entry_for_this_year.empty?
    true
  end

  def revert
    raise "Overthink this ... propably better to only allow single contracts to be reverted"
    end_of_year_date = Date.new(@year).end_of_year.to_date
    AccountingEntry.where(date: end_of_year_date, annually_closing_entry: true).delete_all
    #TODO what to do with terminated contracts (should interest always be deleted)
    #Vielleicht verträge mit terminated at ausschließen
  end

  def self.most_recent_one
    year_closing_entry = AccountingEntry.
        order('date DESC').where(annually_closing_entry: true).
        reject{|e| e.contract.terminated_at.present?}.first
    return nil unless year_closing_entry
    year_closing_entry.date.year
  end

  def self.next_one
    return 7.years.ago.year unless most_recent_one
    most_recent_one + 1
  end

  def self.all
    AccountingEntry.where(annually_closing_entry: true).map{|entry| entry.date.year}.uniq.sort.reverse
  end

  def contracts
    AccountingEntry.only_from_year(@year).where(annually_closing_entry: true).map(&:contract)
  end

  def email_all_closing_statements
    mail_template = MailTemplate.find_by_year(@year)
    contacts_and_contracts_with_email.each do |contact, contracts|
      Email.create!(contact: contact,
                    mail_template: mail_template,
                    year: @year,
                    contracts: contracts)
    end
  end

  def contacts_and_contracts_with_email
    contracts.group_by(&:contact).reject{|contact, contract| contact.blank? || contact.email.blank?}
  end

  def contacts_and_contracts_without_email
    contracts.group_by(&:contact).select{|contact, contract| contact.blank? || contact.email.blank?}
  end

  #TODO: This really belongs some where else
  require 'csv'
  def as_csv
    CSV.generate do |csv|
      csv << ['NRD#', 'Vorname', 'Nachname', 'Email', 'Vorjahressaldo', 'Kontobewegungen', 'Zinsen', 'Saldo Jahresabschluss', 'Dateiname']
      contracts.each do |contract|
        row = []
        row << contract.number
        row << contract.contact.prename
        row << contract.contact.name
        row << contract.contact.email
        row << balance_closing_of_year_before(contract)
        row << movements_excluding_interest(contract)
        row << annual_interest(contract)
        row << balance_closing_of_year(contract)
        row << "#{@year}-NRD_#{contract.number.gsub('-', '')}-#{contract.contact.try(:name).to_s.gsub('ä','ae').gsub('ö','oe').gsub('ü','ue').gsub('ß','ss').
               gsub('Ä','Ae').gsub('Ö','Oe').gsub('Ü','ue').gsub(/\W/,'')}-Jahreskontoauszug.pdf"
        csv << row
      end
    end
  end

  def persisted?
    false
  end
  def to_param
    year
  end

  #We might want to move this into a separate model/presenter soon
  def balance_closing_of_year_before(contract)
    movement = InterestCalculation.new(contract, year: @year).account_movements_with_initial_balance.first
    movement[:amount]
  end
  def movements_excluding_interest(contract)
    movements = InterestCalculation.new(contract, year: @year).account_movements_with_initial_balance
    without_initial_balance = movements.drop(1) # Initial balance
    only_non_interest = without_initial_balance.reject{|m| m[:type] == :interest_entry}
    only_non_interest.map{|m| m[:date].iso8601 + ' ' + m[:amount].to_s}.to_sentence
  end
  def annual_interest(contract)
    end_of_year_date = Date.new(@year).end_of_year.to_date
    closing_entries = AccountingEntry.where(date: end_of_year_date, annually_closing_entry: true, interest_entry: true, contract_id: contract.id)
    # Note: contracts that were repaid during this year do not have an interest-entry where
    # annually_closing_entry=true, that is why we get the latest interest entry here
    interest_entries = AccountingEntry.where(interest_entry: true, contract_id: contract.id).order(:date)

    annual_interest = closing_entries.length > 0 ? closing_entries.first.amount : interest_entries.last.amount
    annual_interest
  end
  def balance_closing_of_year(contract)
    contract.balance(Date.new(@year + 1, 1, 1))
  end

end

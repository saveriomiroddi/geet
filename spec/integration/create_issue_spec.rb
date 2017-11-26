require 'spec_helper'

require_relative '../../lib/geet/git/repository'
require_relative '../../lib/geet/services/create_issue'

describe Geet::Services::CreateIssue do
  let(:repository) { Geet::Git::Repository.new }
  let(:upstream_repository) { Geet::Git::Repository.new(upstream: true) }

  context 'with labels, assignees and milestones' do
    it 'should create an issue' do
      allow(repository).to receive(:remote).with('origin').and_return('git@github.com:donaldduck/testrepo')

      expected_output = <<~STR
        Finding labels...
        Finding milestone...
        Finding collaborators...
        Creating the issue...
        Adding labels bug, invalid...
        Setting milestone 0.0.1...
        Assigning users donald-ts, donald-fr...
        Issue address: https://github.com/donaldduck/testrepo/issues/1
      STR

      actual_output = StringIO.new

      actual_created_issue = VCR.use_cassette("create_issue") do
        described_class.new.execute(
          repository, 'Title', 'Description',
          label_patterns: 'bug,invalid', milestone_pattern: '0.0.1', assignee_patterns: 'nald-ts,nald-fr',
          no_open_issue: true, output: actual_output
        )
      end

      expect(actual_output.string).to eql(expected_output)

      expect(actual_created_issue.number).to eql(1)
      expect(actual_created_issue.title).to eql('Title')
      expect(actual_created_issue.link).to eql('https://github.com/donaldduck/testrepo/issues/1')
    end
  end

  it 'should create an upstream issue' do
    allow(upstream_repository).to receive(:current_branch).and_return('mybranch')
    allow(upstream_repository).to receive(:remote).with('origin').and_return('git@github.com:donaldduck/testrepo')
    allow(upstream_repository).to receive(:remote).with('upstream').and_return('git@github.com:donald-fr/testrepo_u')

    expected_output = <<~STR
      Creating the issue...
      Assigning authenticated user...
      Issue address: https://github.com/donald-fr/testrepo_u/issues/7
    STR

    actual_output = StringIO.new

    actual_created_issue = VCR.use_cassette("create_issue_upstream") do
      described_class.new.execute(upstream_repository, 'Title', 'Description', no_open_issue: true, output: actual_output)
    end

    expect(actual_output.string).to eql(expected_output)

    expect(actual_created_issue.number).to eql(7)
    expect(actual_created_issue.title).to eql('Title')
    expect(actual_created_issue.link).to eql('https://github.com/donald-fr/testrepo_u/issues/7')
  end
end

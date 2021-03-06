module Zeed
  module MailerPatch
    def self.included(base)
      base.send :include, InstanceMethods
      base.class_eval do
        unloadable

        alias_method_chain :issue_edit, :delay
        alias_method_chain :wiki_content_updated, :delay
      end
    end
  end

  module InstanceMethods

    def issue_edit_with_delay(journal, to_users = nil, cc_users = nil)

      if journal.kind_of?(Array)
        journals = journal

        journal = journal.last

        journals.each do |j|
          journal.details.concat(j.details)
        end
      end

      issue = journal.journalized

      if to_users.kind_of?(Array)
        Notification.create(
            :action => 'issue_edit',
            :entity_id => issue.id,
            :param_id => journal.id,
            :param_model => journal.class.name
        )

        to_users = []
        cc_users = []
      else
        to_users = issue.notified_users
        cc_users = issue.notified_watchers - to_users
      end

      issue_edit_without_delay(journal, to_users, cc_users)

    end

    def wiki_content_updated_with_delay(wiki_content, instant = false)

      if wiki_content.kind_of?(Array)
        wiki_content = wiki_content.last
      end

      redmine_headers 'Project' => wiki_content.project.identifier,
                      'Wiki-Page-Id' => wiki_content.page.id
      @author = wiki_content.author
      message_id wiki_content
      recipients = wiki_content.recipients
      cc = wiki_content.page.wiki.watcher_recipients + wiki_content.page.watcher_recipients - recipients
      @wiki_content = wiki_content
      @wiki_content_url = url_for(:controller => 'wiki', :action => 'show',
                                  :project_id => wiki_content.project,
                                  :id => wiki_content.page.title)
      @wiki_diff_url = url_for(:controller => 'wiki', :action => 'diff',
                               :project_id => wiki_content.project, :id => wiki_content.page.title,
                               :version => wiki_content.version)

      unless instant
        Notification.create(
            :action => 'wiki_content_updated',
            :entity_id => wiki_content.page.id,
            :param_id => wiki_content.id,
            :param_model => wiki_content.class.name
        )

        recipients = []
        cc = []
      end

      mail :to => recipients,
           :cc => cc,
           :subject => "[#{wiki_content.project.name}] #{l(:mail_subject_wiki_content_updated, :id => wiki_content.page.pretty_title)}"
    end

  end
end

Mailer.send(:include, Zeed::MailerPatch)
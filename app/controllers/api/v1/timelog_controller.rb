#-- copyright
# OpenProject is a project management system.
#
# Copyright (C) 2012-2013 the OpenProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# See doc/COPYRIGHT.rdoc for more details.
#++

module Api
  module V1

    class TimelogController < TimelogController

      include ::Api::V1::ApiController

      def index
        sort_init 'spent_on', 'desc'
        sort_update 'spent_on' => 'spent_on',
                    'user' => 'user_id',
                    'activity' => 'activity_id',
                    'project' => "#{Project.table_name}.name",
                    'issue' => 'issue_id',
                    'hours' => 'hours'

        cond = ARCondition.new
        if @issue
          cond << "#{Issue.table_name}.root_id = #{@issue.root_id} AND #{Issue.table_name}.lft >= #{@issue.lft} AND #{Issue.table_name}.rgt <= #{@issue.rgt}"
        elsif @project
          cond << @project.project_condition(Setting.display_subprojects_issues?)
        end

        retrieve_date_range
        cond << ['spent_on BETWEEN ? AND ?', @from, @to]

        respond_to do |format|
          format.api  {
            @entry_count = TimeEntry.visible.count(:include => [:project, :issue], :conditions => cond.conditions)
            @entry_pages = Paginator.new self, @entry_count, per_page_option, params['page']
            @entries = TimeEntry.visible.find(:all,
                                      :include => [:project, :activity, :user, {:issue => :tracker}],
                                      :conditions => cond.conditions,
                                      :order => sort_clause,
                                      :limit  =>  @entry_pages.items_per_page,
                                      :offset =>  @entry_pages.current.offset)
          }
        end
      end

      def show
        respond_to do |format|
          format.api
        end
      end

      def create
        @time_entry ||= TimeEntry.new(:project => @project, :issue => @issue, :user => User.current, :spent_on => User.current.today)
        @time_entry.safe_attributes = params[:time_entry]

        call_hook(:controller_timelog_edit_before_save, { :params => params, :time_entry => @time_entry })

        if @time_entry.save
          respond_to do |format|
            format.api  { render :action => 'show', :status => :created, :location => time_entry_url(@time_entry) }
          end
        else
          respond_to do |format|
            format.api  { render_validation_errors(@time_entry) }
          end
        end
      end

      def update
        @time_entry.safe_attributes = params[:time_entry]

        call_hook(:controller_timelog_edit_before_save, { :params => params, :time_entry => @time_entry })

        if @time_entry.save
          respond_to do |format|
            format.api  { head :ok }
          end
        else
          respond_to do |format|
            format.api  { render_validation_errors(@time_entry) }
          end
        end
      end

      def destroy
        if @time_entry.destroy && @time_entry.destroyed?
          respond_to do |format|
            format.html {
              flash[:notice] = l(:notice_successful_delete)
              redirect_to :back
            }
            format.api { head :ok }
          end
        else
          respond_to do |format|
            format.html {
              flash[:error] = l(:notice_unable_delete_time_entry)
              redirect_to :back
            }
            format.api { render_validation_errors(@time_entry) }
          end
        end
      rescue ::ActionController::RedirectBackError
        redirect_to :action => 'index', :project_id => @time_entry.project
      end

    end
  end
end

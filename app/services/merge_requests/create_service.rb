module MergeRequests
  class CreateService < MergeRequests::BaseService
    def execute
      filter_params
      label_params = params[:label_ids]
      merge_request = MergeRequest.new(params.except(:label_ids))
      merge_request.source_project = project
      merge_request.target_project ||= project
      merge_request.author = current_user

      if merge_request.save
        # Fetch fork branch into hidden ref of target repository
        if merge_request.for_fork?
          merge_request.target_project.repository.fetch_ref(
            merge_request.source_project.repository.path_to_repo,
            "refs/heads/#{merge_request.source_branch}",
            "refs/merge-requests/#{merge_request.id}/head"
          )
        end

        merge_request.update_attributes(label_ids: label_params)
        event_service.open_mr(merge_request, current_user)
        notification_service.new_merge_request(merge_request, current_user)
        merge_request.create_cross_references!(merge_request.project, current_user)
        execute_hooks(merge_request)
      end

      merge_request
    end
  end
end

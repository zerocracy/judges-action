# complete code
import logging

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class OctokitError(Exception):
    """Base class for Octokit errors"""
    pass

class NotFoundError(OctokitError):
    """Raised when a resource is not found"""
    pass

class DeprecatedError(OctokitError):
    """Raised when an endpoint is deprecated"""
    pass

class ForbiddenError(OctokitError):
    """Raised when access is forbidden"""
    pass

def unmask_repos(fbe, fact):
    """
    Unmask repositories for a given fact.

    Args:
        fbe (Fbe): Fbe instance
        fact (dict): Fact dictionary

    Returns:
        list: List of unmasked repositories
    """
    logger.info("Unmasking repositories for fact %s", fact)
    try:
        # Get repository workflow runs
        workflow_runs = fbe.octo.repository_workflow_runs(fact['repo'], created=fact['created'])
        if workflow_runs is None:
            raise NotFoundError("Repository workflow runs not found")
        elif isinstance(workflow_runs, list) and len(workflow_runs) == 0:
            raise NotFoundError("No repository workflow runs found")
        elif isinstance(workflow_runs, dict) and 'message' in workflow_runs and workflow_runs['message'] == 'Not Found':
            raise NotFoundError("Repository workflow runs not found")

        # Get workflow run usage
        usage = fbe.octo.workflow_run_usage(fact['repo'], workflow_runs[0]['id'])
        if usage is None:
            raise NotFoundError("Workflow run usage not found")
        elif isinstance(usage, dict) and 'message' in usage and usage['message'] == 'Not Found':
            raise NotFoundError("Workflow run usage not found")

        # Return unmasked repositories
        return [repo for repo in fact['repos'] if repo['id'] in [run['id'] for run in workflow_runs]]

    except NotFoundError as e:
        logger.info("Repository not found: %s", e)
        return []
    except DeprecatedError as e:
        logger.info("Deprecated endpoint: %s", e)
        return []
    except ForbiddenError as e:
        logger.info("Forbidden access: %s", e)
        logger.warning("Will retry next cycle")
        return []
    except Exception as e:
        logger.error("Error unmasking repositories: %s", e)
        return []
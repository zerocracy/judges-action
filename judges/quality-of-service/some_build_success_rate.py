# complete code
import logging

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def some_build_success_rate(fbe, fact):
    """
    Calculate the build success rate for a given fact.

    Args:
        fbe (Fbe): Fbe instance
        fact (dict): Fact dictionary

    Returns:
        float: Build success rate
    """
    logger.info("Calculating build success rate for fact %s", fact)
    try:
        # Unmask repositories
        repos = unmask_repos(fbe, fact)

        # Calculate build success rate
        if len(repos) == 0:
            return 0.0
        else:
            return sum(1 for repo in repos if repo['success']) / len(repos)

    except Exception as e:
        logger.error("Error calculating build success rate: %s", e)
        return 0.0
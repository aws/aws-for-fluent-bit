# Bar Constants
BAR_ACCEPTED_PERCENT_DUPLICATION = 10
BAR_ACCEPTED_PERCENT_LOSS = 10

# The following function will assess the test results
# If the test results are below standard, return false,
# o.w. return true
def bar_raiser(test_results):
    return all(
        # Log loss
        list(
            map(lambda t: int(t["parsed_validation_output"]["percent_loss"]) < BAR_ACCEPTED_PERCENT_LOSS, test_results))

        # Log duplication
        + list(
            map(lambda t: (
                    int(t["parsed_validation_output"]["total_destination"]) == 0 or
                    (int(t["parsed_validation_output"]["duplicate"]) / int(t["parsed_validation_output"]["total_destination"]) * 100) < BAR_ACCEPTED_PERCENT_DUPLICATION
                ),
                test_results
            ))
    )

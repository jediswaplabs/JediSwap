from starkware.starknet.compiler.compile import \
    get_selector_from_name


def get_event_dict_from_execution_info(execution_info):
    event_dict = {}
    raw_events = execution_info.raw_events
    for raw_event in raw_events:
        event_dict[raw_event.keys[0]] = raw_event.data
    return event_dict


def get_event_data(execution_info, event_name):
    event_selector = get_selector_from_name(event_name)
    event_dict = get_event_dict_from_execution_info(execution_info)
    event_data = event_dict.get(event_selector, False)
    return event_data

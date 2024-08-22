#!/bin/bash

# Color scheme
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m' 

# Run awscli with specific profile
run_aws_cli() {
    command=$1
    profile=$2
    aws $command --profile $profile --output json
}

# List all IAM groups
enumerate_groups() {
    profile=$1
    echo -e "${BLUE}Enumerating all IAM groups for profile: ${YELLOW}$profile${NC}"

    groups=$(run_aws_cli "iam list-groups" $profile)
    if [ -z "$groups" ]; then
        echo -e "${RED}Error: Failed to retrieve groups.${NC}"
        exit 1
    fi

    group_names=$(echo $groups | jq -r '.Groups[].GroupName')
    echo
    echo -e "${GREEN}Found Groups:${NC}"
    echo -e "${YELLOW}$group_names${NC}"
}

# Check groups for current user
check_groups_for_current_user() {
    profile=$1

    user_info=$(run_aws_cli "sts get-caller-identity" $profile)
    if [ -z "$user_info" ]; then
        echo -e "${RED}Error: Failed to retrieve user info.${NC}"
        exit 1
    fi

    user_arn=$(echo $user_info | jq -r '.Arn')
    user_name=$(echo $user_arn | awk -F'/' '{print $NF}')
    echo
    echo -e "${BLUE}Current User: ${YELLOW}$user_name${NC}"

    user_groups=$(run_aws_cli "iam list-groups-for-user --user-name $user_name" $profile)
    if [ -z "$user_groups" ]; then
        echo -e "${RED}Error: Failed to retrieve groups for the user.${NC}"
        exit 1
    fi

    echo -e "${GREEN}Groups associated with the current user ($user_name):${NC}"
    group_names=$(echo $user_groups | jq -r '.Groups[].GroupName')
    echo -e "${YELLOW}$group_names${NC}"
}

# Enumerate group policies
enumerate_group_policies() {
    profile=$1
    echo
    echo -e "${BLUE}Enumerating policies for each group.${NC}"

    groups=$(run_aws_cli "iam list-groups" $profile)
    group_names=$(echo $groups | jq -r '.Groups[].GroupName')

    for group_name in $group_names; do
        echo -e "${GREEN}Group: ${YELLOW}$group_name${NC}"

        attached_policies=$(run_aws_cli "iam list-attached-group-policies --group-name $group_name" $profile)
        if [ -n "$attached_policies" ]; then
            echo -e "${BLUE}  Attached Policies:${NC}"
            for policy_arn in $(echo $attached_policies | jq -r '.AttachedPolicies[].PolicyArn'); do
                policy_name=$(run_aws_cli "iam get-policy --policy-arn $policy_arn" $profile | jq -r '.Policy.PolicyName')
                echo -e "${YELLOW}    - $policy_name${NC} (${BLUE}$policy_arn${NC})"
                echo
            done
        fi
    done
}

# Main script execution
if [ "$#" -ne 1 ]; then
    echo -e "${RED}Usage: $0 <aws-profile>${NC}"
    exit 1
fi

profile=$1

enumerate_groups $profile

check_groups_for_current_user $profile

enumerate_group_policies $profile

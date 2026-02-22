#!/bin/bash
#createing a security-group for a web server
echo "befoure doing this operation, make sure you have installed aws cls command line tool and AWS congigured properly."
echo "====================================================================================================================="
read -p "Do you want to continue? (y/n): " choice
if [[ "$choice" != "y" && "$choice" != "Y" ]]; then
    echo "Operation cancelled."
    exit 1
fi
echo "===================================================================================="
#create group session
create_security_group()
{
read -p "Enter Security Group Name: " sg_name
read -p "Enter Security Group Description: " sg_description
# Create the security group
aws ec2 create-security-group --group-name $sg_name --description $sg_description #"newton using trill"
if [ $? -ne 0 ]; then
    echo "Failed to create security group."
    exit 1
fi
echo "Security group '$sg_name' created successfully."
# Authorize inbound rules for HTTP (port 80) and HTTPS (port 443)
aws ec2 authorize-security-group-ingress --group-name $sg_name --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-name $sg_name --protocol tcp --port 22-8000 --cidr 0.0.0.0/0
if [ $? -ne 0 ]; then
    echo "Failed to set inbound rules."
    exit 1
fi
echo "Inbound rules for HTTP and HTTPS set successfully."
echo "Security group '$sg_name' is ready for use with web servers."
echo "===================================================================================="
}
#group Delete session
delete_security_group()
{
read -p "Enter Security Group Name to delete: " sg_name
# Delete the security group
aws ec2 delete-security-group --group-name $sg_name
if [ $? -ne 0 ]; then
    echo "Failed to delete security group."
    exit 1
fi
echo "Security group '$sg_name' deleted successfully."
echo "===================================================================================="
}

#group details
group_details()
{
read -p "Enter Security Group Name to view details: " sg_name
###########################################################################
echo "Security group details"
echo "======================"
aws ec2 describe-security-groups --group-names $sg_name
#aws ec2 describe-security-groups --query "SecurityGroups[*].GroupName" --output table
echo "===================================================================================="
}
#group List
list_security_groups()
{
echo "Listing all security groups"
echo "=========================="
aws ec2 describe-security-groups --query "SecurityGroups[*].GroupName" --output table
echo "===================================================================================="
}
#main script
echo "Please select an option:"
echo "1. Create Security Group"
echo "2. Delete Security Group"
echo "3. View Security Group Details"
echo "4. List All Security Groups"
read -p "Enter your choice (1/2/3/4): " choice
case $choice in
    1) create_security_group ;;
    2) delete_security_group ;;
    3) group_details ;;
    4) list_security_groups ;;
    *) echo "Invalid choice. Please select 1, 2, 3, or 4." ;;
esac

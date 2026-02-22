#!/bin/bash
#for download cls command line tool
echo "befoure doing this operation, make sure you have installed aws cls command line tool and AWS congigured properly."
echo "====================================================================================================================="
read -p "Do you want to continue? (y/n): " choice
if [[ "$choice" != "y" && "$choice" != "Y" ]]; then
    echo "Operation cancelled."
    exit 1
fi
echo "===================================================================================="
create_keypair()
 {
    read -p "please enter the keypair-name : " name
    echo "keypair-name : $name"
    aws ec2 create-key-pair --key-name $name --query 'KeyMaterial' --output text > $name.pem
        if [ $? -eq 0 ]; then
            echo "key pair careated successgully and saved in $name.pem"
            chmod 400 $name.pem && read -p "if you want to see the key pair (Y/n) : "
            if [[ $reply =~ ^[Yy]$ ]]; then
                cat $name.pem
            fi
        else
        echo "Failed to create key pair"
    fi
}
delete_keypair()
 {
    read -p "please enter the keypair-name to delete : " name
    echo "keypair-name to delete : $name"
    aws ec2 delete-key-pair --key-name $name
        if [ $? -eq 0 ]; then
            echo "key pair deleted successgully"
        else
        echo "Failed to delete key pair"
    fi
}
keypair_list()
 {
    echo "Listing all key pairs:"
    #aws ec2 describe-key-pairs --query 'KeyPairs[*].KeyName' --output text
     aws ec2 describe-key-pairs --query "KeyPairs[*].KeyName" --output table
}
#main locaicl
    echo "========================================"
    echo "Key Pair Management Menu:"
    echo "1. Create Key Pair"
    echo "2. Delete Key Pair"
    echo "3. List Key Pairs"
    echo "4. Exit"
    echo "========================================"
    read -p "Please choose an option (1-4): " option
    case $option in
        1)
            create_keypair
            ;;
        2)
            delete_keypair
            ;;
        3)
            keypair_list
            ;;
        4)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid option. Please choose a valid option (1-4)."
            ;;
    esac

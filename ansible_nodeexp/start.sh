# ansible-galaxy collection install -r requirements.yml
ansible-playbook -i openstack_hosts.ini --become run_exporter.yml

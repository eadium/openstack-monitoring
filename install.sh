#!/bin/bash
# pass ip's of compute nodes as an arg to this script 
# ./install.sh 192.168.24.14,92.168.24.15,92.168.24.16
# you may also want to skip some stages with extra args: no_prom, no_stack_exp, no_grafana

# config section
libvirt_port=9178
openstack_exporter_port=9180
openstack_exporter_host=localhost
prometheus_port=9090
conf_dir=/home/stack/monitoring

if [ $# -eq 0 ]
  then
    echo "No arguments supplied" && exit 1
fi

IFS=', ' read -r -a compute_nodes <<<"$1"
for element in "${compute_nodes[@]}"; do
    ssh heat-admin@${element} "
        sudo apt install -y wget 
        wget https://github.com/eadium/openstack-monitoring/raw/master/libvirt_exporter
        chmod +x libvirt_exporter
        sudo ./libvirt_exporter --libvirt.export-nova-metadata --web.listen-address=0.0.0.0:${port} &
        sudo firewall-cmd --zone=public --add-port=9178/tcp --permanent; sudo firewall-cmd --reload
    "
    curl ${element}:${port} || echo Can\'t reach metrics at $element
done

# deploying to localhost
if [[ "$2" != "no_stack_exp" && "$3" != "no_stack_exp" && "$4" != "no_stack_exp"]]; then
    echo "----- Openstack exporter deployment -----"
    podman system prune -af
    sudo cp /etc/openstack/clouds.yaml $conf_dir
    podman run -p $openstack_exporter_port:9180 --network host --name openstack_exporter.ddk -v /home/stack/monitoring/clouds.yaml:/etc/openstack/clouds.yaml -d quay.io/niedbalski/openstack-exporter-linux-amd64:master overcloud
    podman ps
    else echo "---- Skipping openstack exporter deployment -----"
fi

if [[ "$2" != "no_prom" && "$3" != "no_prom" && "$4" != "no_prom"]]; then
    echo "----- Prometheus deployment -----"
    # generate prometheus.yml
    mkdir -p $conf_dir
    curl https://raw.githubusercontent.com/eadium/openstack-monitoring/master/prometheus.yml > $conf_dir/prometheus.yml
    target_libvirt_exporter="      - targets: \['libvirt_exporter_host:libvirt_exporter_port'\]"
    target_openstack_exporter="      - targets: \['openstack_exporter_host:openstack_exporter_port'\]"
    for host in "${compute_nodes[@]}"; do
        sed -i "s/\($target_libvirt_exporter\)/\1\n\1/" $conf_dir/prometheus.yml
        sed -i "0,/libvirt_exporter_host/s//$host/" $conf_dir/prometheus.yml
        sed -i "0,/libvirt_exporter_port/s//$libvirt_port/" $conf_dir/prometheus.yml
    done
    sed -i "/$target_libvirt_exporter/d" $conf_dir/prometheus.yml

    sed -i "s/\($target_openstack_exporter\)/\1\n\1/" $conf_dir/prometheus.yml
    sed -i "0,/openstack_exporter_host/s//$openstack_exporter_host/" $conf_dir/prometheus.yml
    sed -i "0,/openstack_exporter_port/s//$openstack_exporter_port/" $conf_dir/prometheus.yml
    sed -i "/$target_openstack_exporter/d" $conf_dir/prometheus.yml
    cat $conf_dir/prometheus.yml

    podman run -p 9090:9090 -dv "$conf_dir:/etc/prometheus" --network host --name prom.ddk prom/prometheus
    podman ps
    else echo "---- Skipping Prometheus deployment -----"
fi


if [[ "$2" != "no_grafana" && "$3" != "no_grafana" && "$4" != "no_grafana"]]; then
    echo "----- Grafana deployment -----"
    podman run -d --name=grafana -p 3000:3000 --network host --name grafana.ddk grafana/grafana
    podman ps
    else echo "---- Skipping Grafana deployment -----"
fi


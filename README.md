## A collection of stuff to quickly start Openstack monitoring

#### Pass IP's of the compute nodes as an arg to this script:
`./install.sh 192.168.24.14,92.168.24.15,92.168.24.16`
#### you may also want to skip some stages with extra args: `no_prom`, `no_stack_exp`, `no_grafana`, `not_libvirt_exp`


### How to

```bash
curl https://raw.githubusercontent.com/eadium/openstack-monitoring/master/install.sh | bash -s <ip_addrs> <extra_args>
```
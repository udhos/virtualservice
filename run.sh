#!/bin/bash

tmp_dir=tmp
config=config.yaml
template_virtualservice=virtualservice.template

msg() {
    echo >&2 "$0: $@"
}

die() {
    msg "$@"
    exit 1
}

[ -z "$NAMESPACE" ] && die "missing default NAMESPACE=$NAMESPACE"
[ -z "$LABEL_KEY" ] && LABEL_KEY=managed-by
[ -z "$LABEL_VALUE" ] && LABEL_VALUE=repository-name

cat >&2 <<EOF

NAMESPACE=$NAMESPACE
LABEL_KEY=$LABEL_KEY
LABEL_VALUE=$LABEL_VALUE

EOF

mkdir -p $tmp_dir

#
# Create virtual services
#

get_config() {
    cat $config | gojq -r --yaml-input 'keys[] as $k | "\(.[$k] | .namespace),\($k),\(.[$k] | .port),\(.[$k] | .prefix)"' | while read i; do
        namespace=$(echo $i | awk -F, '{print $1}')
        service=$(echo $i | awk -F, '{print $2}')
        port=$(echo $i | awk -F, '{print $3}')
        prefix=$(echo $i | awk -F, '{print $4}')

        [ "$prefix" == null ] && prefix=$service
        [ "$namespace" == null ] && namespace=$NAMESPACE

        echo "$namespace,$service,$port,$prefix"
    done
}

get_existing() {
    kubectl get vs -A -l "$LABEL_KEY=$LABEL_VALUE" -o yaml | gojq -r --yaml-input '.items[].metadata | "\(.namespace),\(.name)"'
}

#
# apply new virtualservices
#
apply() {
    cat $curr_config | while read i; do
        namespace=$(echo $i | awk -F, '{print $1}')
        service=$(echo $i | awk -F, '{print $2}')
        port=$(echo $i | awk -F, '{print $3}')
        prefix=$(echo $i | awk -F, '{print $4}')

        msg "APPLY: namespace:service:port:prefix = $namespace:$service:$port:$prefix"

        tmp=$tmp_dir/virtualservice.yaml.$service
        sed \
            -e "s|{{serviceName}}|$service|g" \
            -e "s|{{prefix}}|$prefix|g" \
            -e "s|{{servicePort}}|$port|g" \
            -e "s|{{namespace}}|$namespace|g" \
            < $template_virtualservice > $tmp
        kubectl apply -f $tmp
    done
}

#
# delete stale virtualservices
#
delete() {
    count=0
    cat $curr_existing | while read i; do
        namespace=$(echo $i | awk -F, '{print $1}')
        service=$(echo $i | awk -F, '{print $2}')

        if grep -qE "^$namespace,$service," $curr_config; then
            # found in config, keep it
            msg "DELETE?: namespace:service = $namespace:$service: KEEP"
        else
            # not found in config, delete it
            count=$(($count + 1))
            msg "DELETE?: namespace:service = $namespace:$service: DELETE (deleted so far: $count)"
            kubectl -n $namespace delete vs $service
        fi
    done
}

#
# main
#

msg "## 1/4: parsing config: $config"
curr_config=$tmp_dir/config
get_config > $curr_config
msg "        found $(wc -l $curr_config | awk '{print $1}') entries in config"

msg "## 2/4: retrieving existing virtualservices from cluster"
curr_existing=$tmp_dir/existing
get_existing > $curr_existing
msg "        found $(wc -l $curr_existing | awk '{print $1}') existing virtualservices"

msg "## 3/4: applying config to cluster"
apply

msg "## 4/4: deleting stale virtualservices from cluster"
delete

package main

import (
	"context"
	"fmt"
	"github.com/davecgh/go-spew/spew"
	cov1helpers "github.com/openshift/library-go/pkg/config/clusteroperator/v1helpers"
	"github.com/pkg/errors"
	"k8s.io/apimachinery/pkg/fields"
	"k8s.io/apimachinery/pkg/watch"
	"k8s.io/client-go/tools/cache"
	"os"
	"path/filepath"
	"time"

	configv1 "github.com/openshift/api/config/v1"
	configclient "github.com/openshift/client-go/config/clientset/versioned"
	"k8s.io/client-go/rest"
	"k8s.io/client-go/tools/clientcmd"
	clientwatch "k8s.io/client-go/tools/watch"
)

func main() {
	config, err := loadKubeConfig()
	if err != nil {
		fmt.Println(errors.Wrap(err, "loading kubeconfig"))
	}

	if err := checkClusterOperators(config); err != nil {
		fmt.Println(err)
	}
}

func loadKubeConfig() (*rest.Config, error) {
	ex, err := os.Executable()
	if err != nil {
		panic(err)
	}
	exPath := filepath.Dir(ex)

	return clientcmd.BuildConfigFromFlags("", filepath.Join(exPath, "kubeconfig"))
}

func checkClusterOperators(config *rest.Config) error {

	stabilityTimeout := 5 * time.Minute
	stabilityContext, cancel := context.WithTimeout(context.Background(), stabilityTimeout)
	defer cancel()

	cc, err := configclient.NewForConfig(config)
	if err != nil {
		return errors.Wrap(err, "failed to create a config client")
	}

	// sel := fields.Everything()
	sel, err := fields.ParseSelector("")
	if err != nil {
		return err
	}

	opListWatcher := cache.NewListWatchFromClient(cc.ConfigV1().RESTClient(),
		"clusteroperators",
		"",
		sel)

	coStableCondition := func(event watch.Event) (bool, error) {
		switch event.Type {
		case watch.Added, watch.Modified:
			cos, ok := event.Object.(*configv1.ClusterOperator)
			if !ok {
				return false, nil
			}
			//spew.Dump(cos)
			fmt.Println(cos.Name)
			//fmt.Println(cov1helpers.IsStatusConditionTrue(cos.Status.Conditions, configv1.OperatorAvailable))
			pStatus := cov1helpers.FindStatusCondition(cos.Status.Conditions, configv1.OperatorProgressing)
			spew.Dump(pStatus)
			fmt.Println(time.Since(pStatus.LastTransitionTime.Time).Seconds())

		}
		// TODO: figure out proper exit condition, returning true will cause an exit
		// is the proper way to handle this to have a selector that will only select
		// cluster operators that are "not stable", i.e. progressing lastTransition < 30 seconds
		// if none are found, return true? else log them
		return false, nil
	}

	_, err = clientwatch.UntilWithSync(
		stabilityContext,
		opListWatcher,
		&configv1.ClusterOperator{},
		nil,
		coStableCondition,
	)
	return nil
}

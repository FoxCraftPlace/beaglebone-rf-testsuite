// Hardware-in-the-Loop pipeline for the BeagleBone Black bench.
// Runs on the pi-host agent: the only node that can reach /dev/bbb-uart,
// /dev/relay0 and the direct Ethernet link to the DUT.

pipeline {
    agent { label 'pi-host' }

    options {
        timeout(time: 20, unit: 'MINUTES')
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '30'))
    }

    stages {
        stage('Environment') {
            steps {
                sh '''
                    set -eu
                    echo "agent user : $(id)"
                    echo "python     : $(python3 --version)"
                    for dev in /dev/bbb-uart /dev/relay0; do
                        if [ -r "$dev" ] && [ -w "$dev" ]; then
                            echo "$dev : read/write ok"
                        else
                            echo "$dev : NO ACCESS"
                            exit 1
                        fi
                    done
                    test -r /etc/bbb-bench/secrets.py
                    echo "secrets    : readable"
                '''
            }
        }

        stage('Prepare') {
            steps {
                sh '''
                    set -eu
                    install -m 600 /etc/bbb-bench/secrets.py config/secrets.py
                    python3 -m venv venv
                    . venv/bin/activate
                    pip install --disable-pip-version-check -r requirements.txt
                '''
            }
        }

        stage('Dry run') {
            steps {
                sh '''
                    set -eu
                    . venv/bin/activate
                    robot --dryrun --output NONE --log NONE --report NONE \
                        tests/serial tests/uboot tests/network tests/ssh tests/logs tests/stress
                '''
            }
        }
    }

    post {
        cleanup {
            sh 'rm -f config/secrets.py'
        }
    }
}
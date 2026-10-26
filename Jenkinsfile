// Hardware-in-the-Loop pipeline for the BeagleBone Black bench.
// Runs on the pi-host agent: the only node that can reach /dev/bbb-uart,
// /dev/relay0 and the direct Ethernet link to the DUT.

pipeline {
    agent { label 'pi-host' }

    triggers {
        cron('H 2 * * *')
    }

    options {
        timeout(time: 30, unit: 'MINUTES')
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
                    mkdir -p results
                    find results -mindepth 1 ! -name .gitkeep -delete
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

        stage('Full suite') {
            steps {
                sh '''
                    set -eu
                    . venv/bin/activate
                    robot --outputdir results \
                        tests/serial tests/uboot tests/network tests/ssh tests/logs tests/stress
                '''
            }
        }
    }

    post {
        always {
            // Safety net for failure, abort and timeout: leave the DUT powered.
            // Release means power on with the NC wiring used on this bench.
            catchError(buildResult: 'FAILURE', stageResult: 'FAILURE') {
                sh '''
                    set -eu
                    . venv/bin/activate
                    PYTHONPATH=libraries python - <<'PY'
import runpy
from RelayPower import RelayPower
c = runpy.run_path("config/constants.py")
RelayPower(c["RELAY_PORT"], c["RELAY_BAUDRATE"],
           c["RELAY_CMD_ENERGIZE_HEX"], c["RELAY_CMD_RELEASE_HEX"]).relay_release()
print("relay released: DUT is powered")
PY
                '''
            }
            sh '''
                if [ -f results/output.xml ]; then
                    echo "WARN entries: $(grep -ac 'level="WARN"' results/output.xml || true)"
                fi
            '''
            archiveArtifacts artifacts: 'results/**', allowEmptyArchive: true
            catchError(buildResult: 'UNSTABLE', stageResult: 'UNSTABLE') {
                robot outputPath: 'results'
            }
        }
        cleanup {
            sh 'rm -f config/secrets.py'
        }
    }
}
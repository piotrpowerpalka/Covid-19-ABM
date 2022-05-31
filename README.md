"# Covid-19-ABM" 
# Download the latest version of GAMA (the model was created using ver. 1.8.1) from https://gama-platform.org/download
# run the model from the command line:
cd headless
nohup ./gama-headless.sh -m 64G -hpc 8 [boundary-conditions-of-sim.xml] [dir-for-the-results] > [logs-file.log] 2>&1

# example:
nohup ./gama-headless.sh -m 128G -hpc 16 sc-rs-2021-09-01-minus20-v17-code9.xml sc-rs-minus20-v17-2021-09-04-19-03-code9 > sc-rs-minus20-v17-2021-09-04-19-03-code9.log 2> 1

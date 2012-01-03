This document describes how to run ensembl-compara ProteinTrees pipeline.

1. Necessary software components:

	* MySQL 5.1		(or higher)
	* Perl 5.6		(or higher)
	* Perl DBI API 1.6	(or higher)

EnsEMBL and BioPerl software:
	* bioperl-live		- (bioperl-1-2-3)
	* bioperl-run		- (1.4) for the CodeML runnable/parser
	* ensembl		- core API on which the rest of ensembl APIs are based
	* ensembl-compara	- Compara API (data objects, db adaptors, pipeline runnables, pipeline configuration)
	* ensembl-analysis	- some of the pipeline runnables live here
	* ensembl-hive		- the system to run pipelines

Refer to the following pages for tips about installation and setting up the environment:
	http://www.ensembl.org/info/docs/api/api_installation.html
	http://www.ensembl.org/info/docs/eHive/installation.html

Any compiled binaries mentioned in ensembl-compara/modules/Bio/EnsEMBL/Compara/PipeConfig/ProteinTrees_conf.pm
( if running outside of Sanger farm you might need to compile your own versions and point at them ) :

        'wublastp_exe'              => '/usr/local/ensembl/bin/wublastp',
        'hcluster_exe'              => '/software/ensembl/compara/hcluster/hcluster_sg',
        'mcoffee_exe'               => '/software/ensembl/compara/tcoffee-7.86b/t_coffee',
        'mafft_exe'                 => '/software/ensembl/compara/mafft-6.707/bin/mafft',
        'mafft_binaries'            => '/software/ensembl/compara/mafft-6.707/binaries',
        'sreformat_exe'             => '/usr/local/ensembl/bin/sreformat',
        'treebest_exe'              => '/software/ensembl/compara/treebest.doubletracking',
        'quicktree_exe'             => '/software/ensembl/compara/quicktree_1.1/bin/quicktree',
        'buildhmm_exe'              => '/software/ensembl/compara/hmmer3/hmmer-3.0/src/hmmbuild',
        'codeml_exe'                => '/usr/local/ensembl/bin/codeml',


2. Configuration of the pipeline

	Nearly all of the pipeline configuration now lives in a single "PipeConfig" file, which is a Perl module:
		ensembl-compara/modules/Bio/EnsEMBL/Compara/PipeConfig/ProteinTrees_conf.pm

	It contains the following subroutines:
		* default_options		    - defines customizable options and their default values.
                                    In the majority of cases you will only need to modify some of these.
                                    Do not rush to run your favourite text editor, as you may also change
                                    any of these options from the command line.

		* pipeline_create_commands	- defines a list of specific shell commands needed to create a pipeline database.
                                    It is unlikely you will need to change it.

		* resource_classes		    - defines a list of resource classes and corresponding farm-specific parameters for each class.
                                    You may need to adjust some of these if running the pipeline on your own farm.

		* pipeline_analyses		    - defines the structure of the pipeline itself - which tasks to run, in which order, etc.
                                    These are the very guts of the pipeline, so make sure you know what you are doing
                                    if you are planning to change anything.

	Since our "PipeConfig" files are Perl modules, they use inheritance to avoid code duplication.
	Specific Compara "PipeConfig" files inherit from ensembl-compara/modules/Bio/EnsEMBL/Compara/PipeConfig/ComparaGeneric_conf.pm ,
	which in turn inherits from ensembl-hive/modules/Bio/EnsEMBL/Hive/PipeConfig/HiveGeneric_conf.pm .

	Various groups in EBI and Sanger that use their own "flavours" of the ProteinTrees pipeline have their own subclasses of it here:
	ensembl-compara/modules/Bio/EnsEMBL/Compara/PipeConfig/Example/ .

3. ProteinTree pipeline-specific parameters (in progress)

        * master_db         - it is a hash of connection parameters to your master database.
                            At the moment ProteinTree pipeline requires a presence of a master database,
                            which has to contain information about your species and species_sets.
                            Refer to ensembl-compara/docs/README-master_database in order to create and correctly set up your own.
                            (We normally maintain one master database thoughout many releases, so it can be a one-off time investment.)


4. Initialization of the pipeline database

	Each of Compara pipelines (being a Hive pipeline) runs off a MySQL database.
	The pipeline database contains both static information
	(general definition of analyses, associated runnables, parameters and resources, dependency rules, etc)
	and runtime information about states of single jobs running on the farm or locally.

	By initialization we mean a short step of converting a "PipeConfig" file into such a pipeline database.
	This is done by feeding the ProteinTrees_conf.pm file to ensembl-hive/scripts/init_pipeline.pl script.
	At this stage you can also override any of the options mentioned in the default_options.

	For example:
		init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::ProteinTrees_conf -password "my_mysql_password" -mlss_id 12345
	(it sets both 'password' and 'mlss_id' options).
	In the same way you can set any other "scalar" parameters.

	If you need to modify second-level values of a "hash option" (such as the '-user' or '-host' of the 'pipeline_db' option),
	the syntax is the following (follows the extended syntax of Getopt::Long) :
		init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::ProteinTrees_conf -pipeline_db -host=myhost -pipeline_db -user=readonly

	Normally, one run of init_pipeline.pl should create you a pipeline database.
	If anything goes wrong and the process does not complete successfully,
	you will need to drop the partially created database in order to try again.

	If the process completes successfully, it will print the recommended command lines
		* to connect to the database (if you want to monitor the progress)
		* to "sync" the database (more about it later) and
		* to run the pipeline

	Please remember that these command lines are for use only with a particular pipeline database,
	and are likely to be different next time you run the pipeline. Moreover, they will contain a sensitive password!
	So don't write them down.


5. Synchronizing ("sync"-ing) the pipeline database

	In order to function properly (to monitor the progress, block and unblock analyses and send correct number of workers to the farm)
	the Hive system needs to maintain certain number of job counters. These counters and associated analysis states are updated
	in the process of "synchronization" (or "sync"). This has to be done once before running the pipeline, and normally the pipeline
	will take care of synchronization by itself and will trigger the 'sync' process automatically.
	However sometimes things go out of sync. Especially when people try to outsmart the scheduler by manually stopping and running jobs :)
	This is when you might want to re-sync the database. It is done by running the ensembl-hive/scripts/beekeeper.pl in "sync" mode:

		beekeeper.pl -url <url-of-your-pipeline-database> -sync


6. Running the pipeline in automatic mode

	As mentioned previously, the usual lifecycle of a Hive pipeline is revolving around the pipeline database.
	There are several "Worker" processes that run on the farm.
	The Workers pick suitable tasks from the database, run them, and report back to the database.
	There is also one "Beekeeper" process that normally loops on a head node of the farm,
	monitors the progress of Workers and whenever needed submits more Workers to the farm
	(since Workers die from time to time for natural and not-so-natural reasons, Beekeeper maintains the correct load).

	So to "run the pipeline" all you have to do is to run the Beekeeper:
		beekeeper.pl -url <url-of-your-pipeline-database> -loop

	In order to make sure this process doesn't die when you disconnect, it is normally run in a "screen session".

	If your Beekeeper process gets killed for some reason, don't worry - you can re-sync and start another Beekeeper process.
	It will pick up from where the previous Beekeeper left it.


7. Monitoring the progress in a MySQL session

	There is a "progress" view from which you can select and see how your jobs are doing:
		SELECT * from progress;

	If you see jobs in 'FAILED' state or jobs with retry_count>0 (which means they have failed at least once and had to be retried),
	you may need to look at the "msg" view in order to find out the reason for the failures:
		SELECT * FROM msg WHERE job_id=1234;	# a specific job
	or
		SELECT * FROM msg WHERE analysis_id=15;	# jobs of a specific analysis
	or
		SELECT * FROM msg;	# show me all messages
	Some of the messages indicate temporary errors (such as temporary lack of connectivity with a database or file),
	but some others may be critical (wrong path to a binary) that will eventually make all jobs of an analysis fail.
	If the "is_error" flag of a message is false, it may be just a diagnostic message which is not critical.


8. Monitoring the progress on a pipeline graph

	Most Compara pipelines have rather complex dependency graphs that guide their execution.
	You may get a better picture if you generate a snapshot of the graph.
	You can do it at any moment after the pipeline database has been initialized and sync'ed:

		generate_graph.pl -url <url-of-your-pipeline-database> -output pt_snapshot.png

	Legend:
		a green oval or octagon is a done analysis
		a yellow one is in progress
		a grey one is blocked (until something else is done)
		a red one is failed (normally a Beekeeper will exit if it encounters a failed analysis)
		a blue arrow is a "dataflow rule" (that generates new jobs)
		a red arrow is a "control rule" (that blocks another analysis until the controlling analysis is done)


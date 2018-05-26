=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

## Generic configuration module for all Compara pipelines

package Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Hive::PipeConfig::EnsemblGeneric_conf');


sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},

        'compara_innodb_schema' => 1,

        'linuxbrew_home'        => $self->o('ENV', 'LINUXBREW_HOME'),
    };
}

sub check_exe_in_cellar {
    my ($self, $exe_path) = @_;
    $exe_path = "Cellar/$exe_path";
    push @{$self->{'_all_exe_paths'}}, $exe_path;
    return $self->o('linuxbrew_home').'/'.$exe_path;
}

sub check_file_in_cellar {
    my ($self, $file_path) = @_;
    $file_path = "Cellar/$file_path";
    push @{$self->{'_all_file_paths'}}, $file_path;
    return $self->o('linuxbrew_home').'/'.$file_path;
}

sub check_dir_in_cellar {
    my ($self, $dir_path) = @_;
    $dir_path = "Cellar/$dir_path";
    push @{$self->{'_all_dir_paths'}}, $dir_path;
    return $self->o('linuxbrew_home').'/'.$dir_path;
}

sub check_exe_in_linuxbrew_opt {
    my ($self, $exe_path) = @_;
    $exe_path = "opt/$exe_path";
    push @{$self->{'_all_exe_paths'}}, $exe_path;
    return $self->o('linuxbrew_home').'/'.$exe_path;
}

sub check_all_executables_exist {
    my $self = shift;
    return unless exists $self->root()->{'linuxbrew_home'};
    my $linuxbrew_home = $self->root()->{'linuxbrew_home'};
    foreach my $p (@{$self->{'_all_dir_paths'}}) {
        $p = $linuxbrew_home.'/'.$p;
        die "'$p' cannot be found.\n" unless -e $p;
        die "'$p' is not a directory.\n" unless -d $p;
    }
    foreach my $p (@{$self->{'_all_file_paths'}}) {
        $p = $linuxbrew_home.'/'.$p;
        die "'$p' cannot be found.\n" unless -e $p;
        die "'$p' is not readable.\n" unless -r $p;
    }
    foreach my $p (@{$self->{'_all_exe_paths'}}) {
        $p = $linuxbrew_home.'/'.$p;
        die "'$p' cannot be found.\n" unless -e $p;
        die "'$p' is not executable.\n" unless -x $p;
    }
}

sub pipeline_create_commands {
    my $self            = shift @_;

    # eHive calls pipeline_create_commands twice: once to know which
    # $self->o() parameters it needs, once to get the actual list of
    # commands ($self->o() values are all present only the second time)
    my $second_pass     = scalar(keys %{$self->root}) > 1;
    # Alternatively, just flag the first pass locally
    #my $second_pass     = $self->{'_first_pass_done'};
    #$self->{'_first_pass_done'} = 1;

    # Pre-checks framework: only run them once we have all the values in $self->o()
    $self->check_all_executables_exist if $second_pass;
    $self->pipeline_checks_pre_init if ($self->can('pipeline_checks_pre_init') and $second_pass);

    return $self->SUPER::pipeline_create_commands if $self->can('no_compara_schema');

    my $pipeline_url    = $self->pipeline_url();
    my $parsed_url      = $second_pass && Bio::EnsEMBL::Hive::Utils::URL::parse( $pipeline_url );
    my $driver          = $second_pass ? $parsed_url->{'driver'} : '';

    # sqlite: no concept of MyISAM/InnoDB
    return $self->SUPER::pipeline_create_commands if( $driver eq 'sqlite' );

    return [
        @{$self->SUPER::pipeline_create_commands},    # inheriting database and hive table creation

            # Compara 'release' tables will be turned from MyISAM into InnoDB on the fly by default:
        ($self->o('compara_innodb_schema') ? "sed 's/ENGINE=MyISAM/ENGINE=InnoDB/g' " : 'cat ')
            . $self->o('ensembl_cvs_root_dir').'/ensembl-compara/sql/table.sql | '.$self->db_cmd(),

            # Compara 'pipeline' tables are already InnoDB, but can be turned to MyISAM if needed:
        ($self->o('compara_innodb_schema') ? 'cat ' : "sed 's/ENGINE=InnoDB/ENGINE=MyISAM/g' ")
            . $self->o('ensembl_cvs_root_dir').'/ensembl-compara/sql/pipeline-tables.sql | '.$self->db_cmd(),

            # MySQL specific procedures
            $driver eq 'mysql' ? ($self->db_cmd().' < '.$self->o('ensembl_cvs_root_dir').'/ensembl-compara/sql/procedures.'.$driver) : (),
    ];
}


=head2 pipeline_create_commands_lfs_setstripe

  Arg[1]      : Arrayef of variable names
  Arg[2]      : (optional) username to become
  Example     : $self->pipeline_create_commands_lfs_setstripe('fasta_dir');
  Description : Helper method to build the commands necessary to stripe a Lustre
                filesystem (if on Lustre). The directories come from calling
                $self->o() on the variable names.
                Optionally, the commands will be prefixed with "become" if the
                directory belongs to another user.
  Returntype  : List of strings (commands)
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub pipeline_create_commands_lfs_setstripe {
    my $self = shift;
    my $dirs = shift;
    my $user = shift;

    # Do we need to "become" someone else ?
    $user = $user ? "become -- $user" : '';

    # Prepare the list of directories
    $dirs = [$dirs] unless ref($dirs);
    my @dirs = map {$self->o($_)} @$dirs;

    # perform "lfs setstripe" only if lfs is runnable and the directory is on lustre:
    my @cmds = map {qq{which lfs && $user lfs getstripe $_ >/dev/null 2>/dev/null && $user lfs setstripe $_ -c -1 || echo "Striping is not available on this system"}} @dirs;
    return @cmds;
}


## Default pipeline_analyses, as in HiveGeneric
sub core_pipeline_analyses {
    my $self = shift;
    return [];
}

## But with options to easily modify the workflow in a subclass
sub pipeline_analyses {
    my $self = shift;

    ## The analysis defined in this file
    my $all_analyses = $self->core_pipeline_analyses(@_);
    ## We add some more analyses
    push @$all_analyses, @{$self->extra_analyses(@_)};

    my %analyses_by_name = map {$_->{'-logic_name'} => $_} @$all_analyses;
    $self->tweak_analyses(\%analyses_by_name);

    my %analyses_to_remove = map {$_ => 1} @{ $self->analyses_to_remove };
    $all_analyses = [grep {!$analyses_to_remove{$_->{'-logic_name'}}} @$all_analyses];

    return $all_analyses;
}


## The following methods can be redefined to add more analyses / remove some, and change the parameters of some core ones
sub extra_analyses {
    my $self = shift;
    return [];
}

sub analyses_to_remove {
    return [];
}

sub tweak_analyses {
    my $self = shift;
    my $analyses_by_name = shift;
}


1;


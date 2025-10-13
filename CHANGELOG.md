# Changelog

## [7.11.0] 2025-10-13

### Added

- [TD-7520] Add Search enhancements for queries with quoted text

### Changed

- [TD-7401] Update td-core version

## [7.10.0] 2025-09-19

### Added

- [TD-7417] Forcemerge options for elastic index hot swap

## [7.7.0] 2025-06-30

### Added

- [TD-7299] Refactor gitlab-ci pipeline and add Trivy check

## [7.6.0] 2025-06-10

### Added

- [TD-7233]
  - Reindex score_groups when a score is deleted and their group is empty
  - Added pagination with Flop for paginate results (scores) of a quality_control
  - Added last execution info in scores search of a quality control
  - If after delete a score, their score group is empty, the score group is deleted too

## [7.5.0] 2025-04-30

### Fixed

- [TD-7226] Enhance SSL configuration handling in production

## [7.4.0] 2025-04-09

### Changed

- License and libraries

### Added

- [TD-7094]
  - Access and delete quality control version
  - Indexing quality control versions with latest score

## [7.3.0] 2025-03-18

### Added

- [TD-6927]
  - Update_main action to update domains
  - Elastic search scroll functionality
  - Score Groups pagination funcionality
  - Get score_groups by dynamic_content
  - Score groups to elastic search

## [7.1.0] 2025-02-05

### Added

- [TD-6862]
  - Scores functionality
  - Control mode specifications
  - Optimize permissions
  - Updates all default analyzers to take `asciifolding` into account.
  - `search_as_you_type` type for identifiers.
  - Defines scope for native and dynamic fields search.

## [7.0.0] 2025-01-13

### Changed

- [TD-6911]
  - update Elixir 1.18
  - update dependencies
  - update Docker RUNTIME_BASE=alpine:3.21
  - remove unused dependencies

## [6.16.0] 2024-12-16

### Added

- [TD-6982] Added SSL and ApiKey configuration for Elasticsearch

## [6.13.0] 2024-10-15

### Fixed

- [TD-6870] Added missing 'resource_ref' on GroupBy and Select queryables

### Changed

- [TD-6773] Update td-core
- [TD-6617] Update td-core

## [6.12.0] 2024-09-23

### Added

- [TD-6220]
  - Sources on DataViews and QualityControls
  - Query generator for QualityControls

## [6.9.2] 2024-07-29

### Added

- [TD-6734] Update td-core

## [6.9.1] 2024-07-26

### Added

- [TD-6733] Update td-core

## [6.9.0] 2024-07-26

### Changed

- [TD-6602], [TD-6723] Update td-core

## [6.8.1] 2024-07-18

### Added

- [TD-6713] Update td-core

## [6.8.0] 2024-07-03

### Added

- [TD-6499] Add content format with data origin

## [6.7.0] 2024-06-13

### Changed

- [TD-6561]
  - Standardise aggregations limits
  - Use keyword list for elastic search configuration
- [TD-6402] IndexWorker improvement

## [6.5.0] 2024-04-30

### Added

- [TD-6535] Update Td-core for Elasticsearch reindex improvements and fix index deletion by name
- [TD-6492] Update td-df-lib to enrich hierarchy path

## [6.4.0] 2024-04-09

### Added

- [TD-6527] Add LICENSE file

### Fixed

- [TD-6401] Fixed Content aggregations have a maximum of 10 values
- [TD-6507] Add Elastic bulk page size for enviroment vars and update core lib

## [6.3.0] 2024-03-18

### Added

- [TD-4110] Allow structure scoped permissions management

## [6.2.0] 2024-02-26

### Added

- [TD-6243] Update TdCore Elasticsearch tests
- [TD-6425] Ensure SSL is configured for release migrations

## [5.20.0] 2023-12-19

### Added

- [TD-6152] Support for execution groups

## [5.17.0] 2023-11-02

### Added

- [TD-6059] Support for QualityControls

## [5.15.0] 2023-10-02

### Added

- [TD-5947] Support for DataViews

## [5.13.0] 2023-09-05

### Added

- [TD-5994] Added initial native functions

## [5.12.0] 2023-06-16

### Added

- [TD-5921] Support for Functions

## [5.11.0] 2023-07-24

### Added

- [TD-5809] Authentication and Authorization for admins on DataViews

## [5.10.0] 2023-07-06

### Added

- [TD-5808] API of enriched DataViews with data structures brought from the dd service

### Changed

- [TD-5912] `.gitlab-ci.yml` adaptations for develop and main branches

## [5.8.0] 2023-06-05

### Added

- [TD-5803] Initial version

# Proposal: Harbor NXT

Author: Prasanth Baskar [bupd](https://github.com/bupd)

## Abstract

Harbor NXT (`goharbor/harbor-nxt`) is an incubation repository for experimental features, providing a community-visible innovation space with a clear graduation path to core Harbor.

## Background

Harbor's stability requirements mean experimental features face high scrutiny, slowing innovation. Contributors with transformative but not-yet-fully-proven ideas may find the contribution process daunting. The effort required to bring a complex feature up to production-ready standards is significant, which can discourage ambitious proposals. Furthermore, there is no official, community-visible space for these promising ideas to be developed collaboratively. They often live in private forks, limiting visibility and the potential for broader community contribution until they are submitted as large, monolithic pull requests. Harbor NXT aims to solve these challenges.

## Proposal

Create `goharbor/harbor-nxt` as an innovation hub for the Harbor community.

### Core Principles
- Lower contribution barrier focused on functional correctness and exploration
- Upstream syncs as often as possible (daily to no less than two weeks)
- Continuous onboarding of new contributors and maintainers

### Contribution Model
The barrier to entry for contributions to `harbor-nxt` will be intentionally lower than for the core project. The focus will be on functional correctness, collaboration, and exploration. This model is designed to empower more contributors and reduce the initial review burden on maintainers for ideas that are not yet production-ready.

### Path to Graduation
Features developed in `harbor-nxt` that prove to be stable and useful can be proposed for inclusion in the core `goharbor/harbor` repository. The graduation process includes:

- Minimum Incubation Period: Features must be actively developed in NXT for at least one release cycle before being considered for graduation.
- Graduation Criteria: A feature is considered ready when it demonstrates community adoption (multiple users testing in diverse environments), stability (no critical bugs for 30+ days), comprehensive test coverage, and complete documentation.
- Proposal Process: The feature champion submits a formal proposal to the core Harbor repository, referencing the NXT implementation history, user feedback, and test results.
- Decision Authority: Core Harbor maintainers vote on graduation proposals. A majority approval is required, with no blocking vetoes from maintainers.
- Stalled Features: Features that show no active development for 6+ months may be archived. Contributors can revive archived features by resuming active development.

### Example Incubation Candidates
- Distribution v3 Integration
- Official ARM Builds
- Podman Support
- Playwright Test Migration
- Scratch/Distroless Images
- CI/CD Pipeline Improvements

## Non-Goals
1. Not a replacement for official Harbor releases
2. Not a permanent fork - goal is upstream contribution
3. Does not bypass core Harbor governance
4. Not a dumping ground for rejected features

## Rationale

### Reduces Maintainer Workload for Emerging Ideas
By providing a dedicated space for incubation, `harbor-nxt` allows the community to collaboratively vet, test, and refine features before they are submitted for formal review. This means that when a feature is proposed for graduation, it has already undergone significant development and validation, reducing the review burden on core maintainers and allowing them to focus on the stability of the main project.

### Increases Community Engagement and Visibility
Centralizing experimental efforts in an official repository makes them visible to the entire community. This transparency encourages broader participation, as contributors can easily discover, test, and collaborate on emerging features. This is a significant improvement over innovative work remaining siloed in private forks until it is nearly complete.

### Accelerates Innovation and De-risks Core Harbor
`harbor-nxt` creates a low-friction environment for rapid prototyping and iteration. At the same time, it acts as a crucial buffer, completely isolating the stable, production-focused `goharbor/harbor` repository from the potential instability of experimental code. This dual benefit allows the Harbor ecosystem to innovate more quickly without compromising the reliability that users depend on.

### Creates a Clear Path for Ambitious Contributions
For large-scale features like ARM builds or Podman support, the path to inclusion can be long and uncertain. `harbor-nxt` provides a clear, officially sanctioned pathway for these efforts to gain momentum, attract contributors, and mature into robust solutions ready for integration into Harbor itself.

### Precedent in the Open Source Community
- Linkerd's Edge Releases: Linkerd provides frequently updated "edge" releases directly from its main development branch, allowing the community to test the latest features separately from official stable releases.
- Istio's Feature Status Phases: Istio manages innovation by classifying features as Alpha, Beta, or Stable, creating a clear lifecycle for community testing and feedback before a feature is considered production-ready.
- CNCF Project Maturity Model: The NXT proposal mirrors the CNCF's own Sandbox-to-Graduation process, applying the same principles of incubation and maturation to features within the Harbor project itself.

### Alternatives Considered
- Feature flags in core repo: adds complexity and risk to core codebase
- Long-lived feature branches: creates merge conflicts and maintenance burden
- Private forks (status quo): limits visibility and collaboration
- Separate CNCF project: unnecessary governance overhead

## Risks and Mitigations
- Upstream divergence: frequent syncs (daily to biweekly), rebase before graduation
- Contributor confusion: clear documentation on when to use each repo
- Maintenance burden: minimal governance, automation for syncs and CI
- Permanent experiments: 6-month archival policy with regular status reviews
- Quality perception: strong branding differentiation, experimental labels on artifacts
- Resource competition: NXT is opt-in, core Harbor priorities take precedence

## Success Metrics

### Quantitative
- 1-2 features graduated within 18 months
- 10+ active contributors within first year
- Features ready for graduation within 6-12 months

### Qualitative
- Contributor satisfaction with NXT vs core Harbor contribution experience
- Reduction in post-graduation bugs for NXT-incubated features
- Quality of collaboration compared to isolated fork development

## Compatibility
- Frequent upstream syncs maintain compatibility (daily to no less than two weeks)
- No production guarantees for NXT builds (API stability, schema compatibility, upgrade paths)
- Graduating features must resolve merge conflicts and integrate without regressions

## Governance

Harbor NXT's governance is intentionally lightweight to nurture new contributions and foster innovation while maintaining alignment with the core Harbor project.

### Relationship with Core Harbor
NXT operates as a semi-autonomous incubation space under the Harbor umbrella. Core Harbor maintainers retain oversight on strategic direction and graduation decisions, but day-to-day operations are managed independently by NXT maintainers. This separation allows NXT to move fast and experiment freely without burdening core maintainers.

### Simplified Contribution Process
Unlike core Harbor's rigorous review requirements, NXT welcomes experimental contributions with a focus on learning and iteration. New contributors can submit ideas without the pressure of production-grade standards, making it an ideal entry point for community members who want to contribute to Harbor's future.

### NXT Maintainers
- Responsible for PR reviews, repository health, upstream syncs, and contributor guidance
- No authority over core Harbor decisions
- Operate independently for day-to-day management
- Defer to core maintainers on strategic direction and graduation
- Actively mentor new contributors and help them understand Harbor's architecture

### Selection Process
- Initial maintainers nominated in this proposal, confirmed by core maintainers
- Additional maintainers nominated by existing NXT maintainers
- Approved by majority vote of core Harbor maintainers
- Contributors who demonstrate sustained engagement can become maintainers

### Decision Making
- Feature acceptance: NXT maintainers review for vision alignment and basic quality (lower bar than core)
- Conflict resolution: NXT maintainers resolve disputes; escalate to core maintainers if needed
- Repository direction: consensus among NXT maintainers, core maintainers have override authority

### Initial Maintainers
- @Vad1mo - Primary steward and initial maintainer

Additional maintainers added as community grows and contributors demonstrate sustained engagement.

## Implementation

### Phase 1: Community Review
- Gather feedback from Harbor community and maintainers
- Address concerns and refine proposal
- Obtain formal approval from core maintainers

### Phase 2: Repository Setup
- Create `goharbor/harbor-nxt` repository
- Seed with copy of `goharbor/harbor`
- Configure branch protection and permissions

### Phase 3: Infrastructure and Governance
- Configure CI/CD pipeline using GitHub Actions
- Automated builds creating container images for every PR
- Push images to publicly accessible registry
- PR commenting with image tags for easy testing
- Create CONTRIBUTING.md with contribution process
- Establish communication channels (Slack channel, mailing list tag)

### Phase 4: Active Development
- Open repository for community contributions
- Begin work on initial candidate features
- Conduct first upstream sync
- Hold initial community meeting to coordinate efforts

### Ongoing Operations
- Upstream syncs as often as possible (daily to no less than two weeks)
- Quarterly metrics reviews and community updates
- Continuous onboarding of new contributors and maintainers

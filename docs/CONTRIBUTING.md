# Contributing to CollateraX

Thank you for your interest in contributing to CollateraX! We're excited to have you join our community of contributors. This document provides guidelines and instructions for contributing to the project.

## Code of Conduct

By participating in this project, you agree to abide by our Code of Conduct. Please read it before contributing.

## How Can I Contribute?

There are many ways you can contribute to CollateraX:

### Reporting Bugs

If you find a bug in the application, please create an issue in our GitHub repository with the following information:

- A clear, descriptive title
- Steps to reproduce the issue
- Expected behavior
- Actual behavior
- Screenshots (if applicable)
- Environment details (browser, OS, etc.)

### Suggesting Enhancements

We welcome suggestions for enhancements! Please create an issue with:

- A clear, descriptive title
- A detailed description of the proposed enhancement
- Any relevant mockups or examples
- Why this enhancement would be valuable

### Pull Requests

We actively welcome pull requests:

1. Fork the repository
2. Create a new branch from `main`
3. Make your changes
4. Run tests and ensure they pass
5. Submit a pull request

### First-Time Contributors

Not sure where to start? Look for issues labeled "good first issue" or "help wanted" in our GitHub repository.

## Development Setup

### Prerequisites

- Node.js 18.0 or later
- npm or yarn
- Git

### Local Development

1. Clone your fork of the repository:
   ```bash
   git clone https://github.com/yourusername/CollateraX.git
   cd CollateraX
   ```

2. Install dependencies:
   ```bash
   npm install
   # or
   yarn install
   ```

3. Create a `.env.local` file based on `.env.example`:
   ```bash
   cp .env.example .env.local
   ```

4. Start the development server:
   ```bash
   npm run dev
   # or
   yarn dev
   ```

5. Open [http://localhost:3000](http://localhost:3000) in your browser.

## Coding Guidelines

### JavaScript/TypeScript

- We use TypeScript for type safety
- Follow the ESLint configuration in the project
- Write meaningful variable and function names
- Add comments for complex logic
- Use async/await for asynchronous code

### React Components

- Use functional components with hooks
- Keep components small and focused on a single responsibility
- Use TypeScript interfaces for props
- Follow the component structure in the project

### CSS/Styling

- We use Tailwind CSS for styling
- Follow the existing design system
- Use responsive design principles
- Avoid inline styles

### Testing

- Write tests for new features
- Ensure existing tests pass
- Follow the testing patterns in the project

## Pull Request Process

1. Update the README.md or documentation with details of changes if appropriate
2. Update the CHANGELOG.md with details of changes
3. The PR should work on the latest version of the codebase
4. Include screenshots for UI changes
5. Link any related issues in the PR description

## Commit Messages

We follow conventional commits for our commit messages:

- `feat:` for new features
- `fix:` for bug fixes
- `docs:` for documentation changes
- `style:` for formatting changes
- `refactor:` for code refactoring
- `test:` for adding or modifying tests
- `chore:` for maintenance tasks

Example: `feat: add wallet connection component`

## Code Review Process

All submissions require review:

1. A maintainer will review your PR
2. Feedback may be provided for necessary changes
3. Once approved, a maintainer will merge your PR

## Community

Join our community:

- Discord: [discord.gg/yieldpilot](https://discord.gg/yieldpilot)
- Twitter: [@YieldPilot_ai](https://twitter.com/YieldPilot_ai)

## Questions?

If you have any questions, feel free to reach out to us on Discord or create an issue on GitHub.

Thank you for contributing to CollateraX!

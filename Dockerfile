# Use Node.js LTS version
FROM node:20-alpine

# Create app directory
WORKDIR /usr/src/app

# Copy package.json
COPY src/package.json ./

# Install dependencies (using npm install instead of npm ci)
RUN npm install

# Bundle app source
COPY src/ .

# Expose port
EXPOSE 3000

# Start the application
CMD [ "npm", "start" ]

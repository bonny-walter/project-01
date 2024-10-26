FROM ubuntu/apache2

# Update and upgrade the system
RUN apt update && apt upgrade -y

# Copy the web application files to the Apache directory
COPY html-web-app/ /var/www/html/

# Expose port 80 for HTTP traffic
EXPOSE 80

# Start Apache in the foreground
CMD ["apache2ctl", "-D", "FOREGROUND"]